{ pkgs, ... }:
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
  # (NHI) *before* suspend and rebind it *after* resume, via the symmetric
  # system-sleep hook (powerDownCommands on the way in, powerUpCommands on the
  # way out). This replaces the old `tb-redock` service, whose "surgical"
  # deauth/reauth almost never worked (0/9 and 0/5 in recent boots) and which
  # ended up doing this exact NHI rebind on nearly every resume anyway.
  # See docs/adr/0008-thunderbolt-teardown-around-sleep.md.
  #
  # No retry/verify logic on the NHI rebind itself: a clean tear-down/bring-up is
  # reliable (the rebind was 9-for-9 historically) and a rare failed rebind costs a
  # replug, not a hang. The unbound NHIs are recorded in /run so resume rebinds
  # exactly them; the file lives on tmpfs, so a cold boot (kernel binds the NHIs
  # itself) finds nothing to do. Steps log with a `[tb-sleep]` tag under
  # systemd-suspend.service.
  #
  # The rebind alone still left the external DP dark after long (overnight) sleeps.
  # amdgpu probes its DP connectors during kernel resume — which runs *before* this
  # hook rebinds the fabric — so the DP-over-TB tunnel isn't up yet and it gives up
  # with `retrieve_link_cap: Read receiver caps dpcd data failed` and no retry. A
  # short nap won the race (dock/monitor never dropped their link); an overnight
  # sleep lost it, leaving the monitor black until a reboot. So resume now also
  # forces an amdgpu DP-connector re-detect once the tunnel is back — a bounded,
  # docked-only poll. See the "Update (2026-07-01)" section of ADR 0008.
  powerManagement.powerDownCommands = ''
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

    # Record whether an external DP monitor was lit at suspend, so resume knows to
    # force a connector re-detect (see powerUpCommands). amdgpu's external
    # connectors are card1-DP-* — the internal panel card1-eDP-1 is excluded by the
    # glob (it has no "-DP-" substring), so this only trips when a dock display is
    # actually driving something.
    ${pkgs.coreutils}/bin/rm -f /run/tb-dp-was-connected
    if ${pkgs.gnugrep}/bin/grep -qx connected /sys/class/drm/card*-DP-*/status 2>/dev/null; then
      : > /run/tb-dp-was-connected
      echo "$tag external DP was connected; will re-detect on resume"
    fi
  '';
  powerManagement.powerUpCommands = ''
    tag="[tb-sleep]"; drv=/sys/bus/pci/drivers/thunderbolt
    if [ -f /run/tb-nhi-unbound ]; then
      while read -r n; do
        if echo "$n" > "$drv/bind" 2>/dev/null; then
          echo "$tag rebound $n"
        else
          echo "$tag rebind $n failed (already bound?)"
        fi
      done < /run/tb-nhi-unbound
      ${pkgs.coreutils}/bin/rm -f /run/tb-nhi-unbound
    fi

    # Relight the external display. The rebind above brings the Thunderbolt fabric
    # back, but bolt authorization and DP-tunnel allocation through the dock are
    # asynchronous and take a beat — longer after an overnight sleep, once the dock
    # and monitor have dropped their own link. amdgpu already probed its DP
    # connectors during the kernel resume that ran *before* this hook, found no
    # tunnel, and gave up ("retrieve_link_cap: Read receiver caps dpcd data failed")
    # with no retry — which is why a short nap resumes the monitor but an overnight
    # sleep leaves it black until a reboot. So once the tunnel is back, force amdgpu
    # to re-detect every DP connector; the state change emits a hotplug that
    # relights the panel and hands niri its output. Bounded ~8s poll, breaks as soon
    # as a connector reads connected, and only runs when a DP monitor was lit at
    # suspend — an undocked resume skips it entirely and adds no delay.
    if [ -f /run/tb-dp-was-connected ]; then
      ${pkgs.coreutils}/bin/rm -f /run/tb-dp-was-connected
      ok=0
      for i in 1 2 3 4 5 6 7 8; do
        ${pkgs.coreutils}/bin/sleep 1
        for s in /sys/class/drm/card*-DP-*/status; do
          [ -e "$s" ] && echo detect > "$s" 2>/dev/null
        done
        if ${pkgs.gnugrep}/bin/grep -qx connected /sys/class/drm/card*-DP-*/status 2>/dev/null; then
          echo "$tag external DP re-detected after $i s"
          ok=1
          break
        fi
      done
      [ "$ok" = 1 ] || echo "$tag external DP still down after 8s (dock/tunnel not ready?)"
      ${pkgs.systemd}/bin/udevadm trigger --subsystem-match=drm --action=change 2>/dev/null || true
    fi
  '';

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
  '';

  # TLP is configured in ./framework-tlp-advanced.nix; keep PPD off to avoid overlap
  services.power-profiles-daemon.enable = false;
  services.tlp.enable = true;

  # Leave CPU scaling to TLP to avoid duelling tuners
  services.auto-cpufreq.enable = false;
}
