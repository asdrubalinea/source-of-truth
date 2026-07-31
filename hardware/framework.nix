{ pkgs, ... }:
let
  # ---------- Thunderbolt dock: tear down around s2idle, don't repair on resume ----------
  # The only sleep state this Framework exposes is s2idle (no S3; ZFS rules out
  # hibernation — see boot.nix). Suspending with the dock's USB4 tunnels live
  # caused two problems: an intermittent dead-on-resume *hang* (the box entered
  # s2idle and never came back — forced power-off the only recovery, and only
  # ever while docked), and, on the resumes that did survive, a dock that read
  # as authorized but re-enumerated nothing behind it (USB, ethernet, and the
  # external displays all ride those tunnels) until a physical replug.
  #
  # So rather than repair a half-restored resume, we take the USB4 controllers
  # out of the suspend path entirely: unbind every Thunderbolt host controller
  # (NHI) *before* suspend and rebind it *after* resume. This runs from the
  # `tb-sleep` systemd service below (tbSleepDown on the way in, tbSleepUp on the
  # way out) — it replaces the old `tb-redock` service, whose "surgical"
  # deauth/reauth almost never worked (0/9 and 0/5 in recent boots) and which
  # ended up doing this exact NHI rebind on nearly every resume anyway.
  # See docs/adr/0008-thunderbolt-teardown-around-sleep.md.
  #
  # No retry/verify logic on the NHI rebind itself: a clean tear-down/bring-up is
  # reliable (the rebind was 9-for-9 historically) and a rare failed rebind costs a
  # replug, not a hang. The unbound NHIs are recorded in /run so resume rebinds
  # exactly them; the file lives on tmpfs, so a cold boot (kernel binds the NHIs
  # itself) finds nothing to do. Steps log with a `[tb-sleep]` tag under the
  # tb-sleep.service unit.
  #
  # The rebind alone still left the external DP *wrong* after long (overnight)
  # sleeps — first dark, later back but capability-pruned. Both are the same race:
  # amdgpu probes a DP connector the instant its tunnel appears and never probes it
  # again. Resume therefore also runs a capability check, and software-replugs any
  # panel that came back worse than it went to sleep. See ADR 0008 (2026-07-31).
  #
  # Both hooks run from systemd's near-empty sleep environment, so they get an
  # explicit PATH rather than spelling out a store path per call — they do enough
  # real work now that inline paths drowned the logic.
  sleepPath = pkgs.lib.makeBinPath [ pkgs.coreutils pkgs.systemd ];

  tbSleepDown = pkgs.writeShellScript "tb-sleep-down" ''
    export PATH=${sleepPath}
    tag="[tb-sleep]"; drv=/sys/bus/pci/drivers/thunderbolt
    : > /run/tb-nhi-unbound
    for d in "$drv"/0000:*; do
      [ -e "$d" ] || continue
      n=''${d##*/}
      echo "$n" >> /run/tb-nhi-unbound
      if echo "$n" > "$drv/unbind" 2>/dev/null; then
        echo "$tag unbound $n"
      else
        echo "$tag unbind $n failed"
      fi
    done

    # Snapshot what each lit external panel could do, so resume can tell "came back"
    # from "came back degraded". amdgpu's external connectors are card1-DP-*; the
    # internal panel card1-eDP-1 has no "-DP-" substring and is excluded by the glob,
    # so an undocked suspend records nothing and resume skips the whole check.
    #
    # Keyed by EDID hash rather than connector name, because the connector follows
    # the *port*, not the panel — the portable has been DP-7 (dock) and DP-2 (direct
    # USB4). The value is the connector's mode count: sysfs prints `modes` one line
    # per mode *including* per-refresh duplicates (the portable lists 2560x1440 four
    # times, for 60/144/120/100), so the count catches a refresh-rate pruning and not
    # just a resolution one.
    #
    # High-water mark, never narrowed: suspending while a panel is already degraded
    # must not enshrine the degraded list as the baseline. /run is tmpfs so a cold
    # boot starts clean — which is correct, since a cold boot probes every panel with
    # the fabric already settled and therefore sees its true capability.
    mkdir -p /run/tb-dp
    : > /run/tb-dp/expected
    for s in /sys/class/drm/card*-DP-*/status; do
      d=''${s%/status}
      [ "$(cat "$s" 2>/dev/null)" = connected ] || continue
      [ -s "$d/edid" ] || continue
      key=$(sha256sum < "$d/edid" | cut -c1-16)
      cur=$(wc -l < "$d/modes")
      old=0
      [ -f "/run/tb-dp/$key" ] && old=$(cat "/run/tb-dp/$key")
      [ "$cur" -gt "$old" ] && echo "$cur" > "/run/tb-dp/$key"
      echo "$key ''${d##*/}" >> /run/tb-dp/expected
      echo "$tag ''${d##*/} lit at suspend: $cur modes (baseline $(cat "/run/tb-dp/$key"))"
    done
  '';

  tbSleepUp = pkgs.writeShellScript "tb-sleep-up" ''
    export PATH=${sleepPath}
    tag="[tb-sleep]"; drv=/sys/bus/pci/drivers/thunderbolt
    if [ -f /run/tb-nhi-unbound ]; then
      while read -r n; do
        if echo "$n" > "$drv/bind" 2>/dev/null; then
          echo "$tag rebound $n"
        else
          echo "$tag rebind $n failed (already bound?)"
        fi
      done < /run/tb-nhi-unbound
      rm -f /run/tb-nhi-unbound
    fi

    # Nothing external was lit at suspend — undocked resume, no display work to do.
    [ -s /run/tb-dp/expected ] || exit 0

    # Connector directory currently showing the panel with EDID key $1, if any.
    conn_for() {
      for s in /sys/class/drm/card*-DP-*/status; do
        d=''${s%/status}
        [ "$(cat "$s" 2>/dev/null)" = connected ] || continue
        [ -s "$d/edid" ] || continue
        [ "$(sha256sum < "$d/edid" | cut -c1-16)" = "$1" ] && { echo "$d"; return 0; }
      done
      return 1
    }

    # A physical unplug/replug, in software. `0` releases the sink and drops the
    # link to dc_connection_none; `1` runs a full dc_link_detect(DETECT_REASON_HPD)
    # — fresh DPCD link-cap verification, fresh EDID, rebuilt mode list, hotplug
    # event to userspace. $1 is a connector dir (card1-DP-7); the debugfs dir is
    # named after the connector (DP-7) under the DRM device, which is reachable by
    # both its PCI address and its minor-number symlink, hence the glob.
    #
    # This is the ONLY thing that re-probes a DP connector from userspace on amdgpu.
    # Writing `detect` to the connector's sysfs `status` — what this hook used to do
    # — cannot work: amdgpu_dm_connector_detect() just reports the cached
    # `dc_sink != NULL` and never touches the link.
    replug() {
      n=''${1##*/}; n=''${n#*-}
      for th in /sys/kernel/debug/dri/*/"$n"/trigger_hotplug; do
        [ -e "$th" ] || continue
        echo 0 > "$th" 2>/dev/null || return 1
        sleep 2
        echo 1 > "$th" 2>/dev/null || return 1
        sleep 3
        return 0
      done
      return 1
    }

    # Phase 1 — wait for every panel that was lit at suspend to come back.
    # Deliberately not "any DP connector reads connected", which is what this used
    # to test: the OLED hangs off a direct USB4 port and is back within a second,
    # so that test tripped instantly and the hook declared victory ~5s before the
    # dock's panel had even reappeared. Each panel is matched by its own EDID.
    for i in $(seq 1 20); do
      missing=0; back=0
      while read -r key name; do
        if conn_for "$key" >/dev/null; then back=$((back + 1)); else missing=1; fi
      done < /run/tb-dp/expected
      [ "$missing" = 0 ] && break
      # Not one panel back after 8s means this is an undocked resume — suspended at
      # the desk, woken up somewhere else. Nothing is coming; don't spend the rest
      # of the budget proving it. A dock that is merely slow always has the
      # direct-USB4 OLED back long before this, so it keeps the full 20s.
      [ "$i" -ge 8 ] && [ "$back" = 0 ] && break
      sleep 1
    done
    [ "$missing" = 0 ] && echo "$tag all external panels back after ''${i}s" \
      || echo "$tag some external panels still absent after ''${i}s; forcing detect"

    # A panel that never came back is the old black-screen failure: amdgpu probed
    # while the tunnel was down, got nothing, and gave up. Force a detect on every
    # *disconnected* external connector — costs nothing when there's genuinely
    # nothing there, and there is no display to flicker.
    if [ "$missing" != 0 ]; then
      for s in /sys/class/drm/card*-DP-*/status; do
        d=''${s%/status}
        [ "$(cat "$s" 2>/dev/null)" = connected ] && continue
        n=''${d##*/}; n=''${n#*-}
        for th in /sys/kernel/debug/dri/*/"$n"/trigger_hotplug; do
          [ -e "$th" ] && echo 1 > "$th" 2>/dev/null
        done
      done
      sleep 3
    fi

    # Phase 2 — a panel can also come back *connected but degraded*. amdgpu probes
    # the connector the moment the tunnel appears; if the dock's retimers are still
    # settling, the link trains below its real capability, mode validation prunes
    # everything that link can't carry, and nothing ever re-probes. The portable
    # comes back with 4 modes instead of 8 (60Hz and 1080p only, no 144/120/100),
    # kanshi's pinned 2560x1440@144 then can't apply, and because kanshi commits a
    # profile atomically the ENTIRE profile aborts:
    #   output 'DP-7' doesn't support mode '2560x1440@144.000000Hz'
    # which is why the felt symptom is "the portable resumes at a junk resolution
    # and only a replug fixes it". So: replug it, in software, until its mode list
    # is back. Only degraded panels are touched, so a healthy resume stays silent
    # and adds no flicker.
    while read -r key name; do
      want=$(cat "/run/tb-dp/$key" 2>/dev/null || echo 0)
      for try in 1 2 3; do
        d=$(conn_for "$key") || { echo "$tag $name never came back"; break; }
        have=$(wc -l < "$d/modes")
        if [ "$have" -ge "$want" ]; then
          [ "$try" = 1 ] || echo "$tag ''${d##*/} restored to $have modes"
          break
        fi
        echo "$tag ''${d##*/} came back degraded ($have of $want modes) — replug $try/3"
        replug "$d" || { echo "$tag no trigger_hotplug for ''${d##*/}; left degraded"; break; }
      done
    done < /run/tb-dp/expected

    udevadm trigger --subsystem-match=drm --action=change 2>/dev/null || true
  '';
in
{
  imports = [
    ./framework-tlp-advanced.nix
  ];

  # Install Framework-specific tools for hardware monitoring
  environment.systemPackages = with pkgs; [
    fw-ectool
    framework-tool
  ];

  systemd.services = {
    disable-fingerprint-led = {
      description = "Disable Framework Laptop Fingerprint LED at boot";
      wantedBy = [ "multi-user.target" ];
      after = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        ExecStart = "${pkgs.fw-ectool}/bin/ectool led power off";
      };
    };

    set-default-brightness = {
      description = "Set default brightness level";
      wantedBy = [ "multi-user.target" ];
      after = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        ExecStart = "${pkgs.brightnessctl}/bin/brightnessctl set 42%";
      };
    };

    # Suspend/resume hook for the Thunderbolt teardown (see the tbSleepDown/tbSleepUp
    # comment in the let block). Replaces the deprecated
    # powerManagement.powerDownCommands/powerUpCommands (removed in NixOS 26.11) with
    # the exact semantics the nixos `sleep-actions` service used: pulled in `before`
    # sleep.target so ExecStart runs before the box suspends, and StopWhenUnneeded so
    # the unit is stopped once sleep.target is no longer needed on resume — firing
    # ExecStop. oneshot + RemainAfterExit keeps it "active" across the sleep so the
    # stop (and thus ExecStop) only happens on the way out.
    tb-sleep = {
      description = "Thunderbolt teardown around s2idle + external-DP repair on resume";
      wantedBy = [ "sleep.target" ];
      before = [ "sleep.target" ];
      unitConfig.StopWhenUnneeded = true;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = tbSleepDown;
        ExecStop = tbSleepUp;
        # ExecStop's worst case is ~35s (20s waiting for a panel that never returns,
        # then 3 replug cycles at 5s). Well under the 90s default, but pinned so a
        # future retry budget can't silently start getting SIGKILLed mid-replug.
        TimeoutStopSec = "120s";
      };
    };
  };

  # Services
  services = {
    fwupd = {
      enable = true;
      extraRemotes = [ "lvfs-testing" ];
    };

    # Hibernation is unavailable here: ZFS root forces `nohibernate` (pool
    # corruption hazard) and the firmware exposes no S3. So `suspend-then-
    # hibernate`/`hibernate` would degrade to a permanent s2idle that never
    # powers off — use plain `suspend` (s2idle/S0ix), the only real sleep state.
    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandlePowerKey = "suspend";
    };

    # Enable thermal management to prevent overheating
    thermald.enable = true;

    # Enable TRIM for SSD health
    fstrim.enable = true;
  };

  # Diagnostic breadcrumb: log each device as it suspends, so if a dead-on-resume
  # hang ever survives the teardown above, the (persistent) journal names the
  # last device that made it down — the next suspect (likely the MT7925 Wi-Fi).
  # Only emits during suspend/resume. See ADR 0008.
  systemd.tmpfiles.rules = [ "w /sys/power/pm_debug_messages - - - - 1" ];

  # Force the MT7925 (RZ717) Wi-Fi to power/control=on. This box's only sleep state
  # is s2idle and its PCIe power-gating doesn't re-enumerate: once this chip is
  # runtime-suspended it wedges in "driver own failed" (-EIO) and only a cold power
  # cycle recovers it. Neither TLP denylist gets us to `on` — they merely make TLP
  # *skip* the device; the mt7925e driver itself enables runtime PM (sets
  # power/control=auto) when it binds. So this rule must fire on `bind` (after probe),
  # not just `add`, to win over the driver — an `add`-only rule is silently reverted
  # to `auto` the moment the driver attaches. Matching by ID (14c3:0717) survives bus
  # renumbering. Child pinned `on` keeps its parent root port (00:02.3) active too.
  services.udev.extraRules = ''
    ACTION=="add|bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x14c3", ATTR{device}=="0x0717", ATTR{power/control}="on"

    # Stop peripherals from waking the box out of s2idle while the lid is shut.
    # This Framework's only sleep state is s2idle and it already "didn't reach
    # deepest state" (no true S0i3), so any wake source that fires on a timer
    # turns a closed-lid suspend into a wake/re-suspend loop: logind sees the lid
    # still closed on each spurious resume and immediately re-suspends. One
    # overnight run logged 742 suspend cycles (~1 every 41s) and flattened the
    # battery — every wake spins the CPU/radios/GPU back up. Both devices below
    # were `power/wakeup=enabled` and neither can be used from a closed lid, so
    # denying their wakeup is pure upside. Matched by stable ID so bus
    # renumbering doesn't lose them.
    #   046d:c547 = Logitech USB Receiver (wireless mouse/kbd dongle)
    #   PIXA3854  = internal I2C-HID touchpad
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c547", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="i2c", KERNEL=="i2c-PIXA3854:00", ATTR{power/wakeup}="disabled"
  '';

  # TLP is configured in ./framework-tlp-advanced.nix; keep PPD off to avoid overlap
  services.power-profiles-daemon.enable = false;
  services.tlp.enable = true;

  # Leave CPU scaling to TLP to avoid duelling tuners
  services.auto-cpufreq.enable = false;
}
