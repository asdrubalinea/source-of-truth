{ pkgs, lib, ... }:
let
  # tb-redock: rebuild Thunderbolt dock tunnels after s2idle resume (see service below).
  tbRedock = pkgs.writeShellScript "tb-redock" ''
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.findutils ]}:$PATH
    tag="[tb-redock]"; log() { echo "$tag $*"; }
    TBDEV=/sys/bus/thunderbolt/devices

    # Poll up to ~8s for a non-host TB device (X-Y, Y>=1; host routers are X-0) to reappear.
    dock=""
    for _ in $(seq 1 16); do
      for d in "$TBDEV"/[0-9]-[1-9]*; do [ -e "$d" ] && { dock="$d"; break; }; done
      [ -n "$dock" ] && break
      sleep 0.5
    done
    if [ -z "$dock" ]; then log "no thunderbolt dock present; nothing to do"; exit 0; fi

    usb_count() { find /sys/bus/usb/devices -maxdepth 1 -type l | wc -l; }
    name=$(basename "$dock"); domain="''${name%%-*}"
    deauth=$(cat "$TBDEV/domain''${domain}/deauthorization" 2>/dev/null || echo 0)
    auth=$(cat "$dock/authorized" 2>/dev/null || echo "?")
    before=$(usb_count)
    log "dock=$name domain=$domain deauthorization=$deauth authorized=$auth usb_before=$before"

    # Tier 1 (surgical): deauth->reauth to tear down stale tunnels and rebuild them.
    if [ -w "$dock/authorized" ]; then
      if [ "$deauth" = "1" ] && [ "$auth" = "1" ]; then
        log "tier1: deauthorizing $name"
        echo 0 > "$dock/authorized" 2>/dev/null \
          && { sleep 1; log "tier1: authorized now=$(cat "$dock/authorized" 2>/dev/null)"; } \
          || log "tier1: deauthorize write failed"
      fi
      log "tier1: authorizing $name"
      echo 1 > "$dock/authorized" 2>/dev/null || log "tier1: authorize write failed"
      sleep 3   # re-tunnel + USB re-enumeration is async
    fi
    after=$(usb_count); log "usb_after_tier1=$after"

    # Tier 2 (escalation): only if Tier 1 did not bring USB devices back.
    if [ "$after" -le "$before" ]; then
      log "tier1 did not restore devices; escalating to PCI rebind"
      nhi_path=$(dirname "$(readlink -f "$TBDEV/domain''${domain}")")
      nhi=$(basename "$nhi_path")
      if [ "$(basename "$(readlink -f "$nhi_path/driver" 2>/dev/null)")" = "thunderbolt" ]; then
        log "tier2: rebinding NHI $nhi"
        echo "$nhi" > /sys/bus/pci/drivers/thunderbolt/unbind 2>/dev/null || log "tier2: unbind failed"
        sleep 1
        echo "$nhi" > /sys/bus/pci/drivers/thunderbolt/bind   2>/dev/null || log "tier2: bind failed"
        sleep 3
        log "usb_after_tier2=$(usb_count)"
      else
        log "tier2: could not resolve NHI PCI function for domain''${domain}"
      fi
    fi
    log "done"
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

  # ---------- Thunderbolt dock: software "replug" on s2idle resume ----------
  # On s2idle resume boltd re-authorizes the enrolled dock (CalDigit TS3 Plus,
  # security level iommu+user) — `authorized` flips back to 1 — but the kernel
  # does NOT rebuild the Thunderbolt PCIe/USB tunnels behind it. Net effect: the
  # dock has power and reads as authorized, yet nothing behind it re-enumerates
  # (USB, ethernet, and DP-over-TB all ride those tunnels), until a physical
  # unplug/replug forces a full re-tunnel. The usual "switch to S3/deep" advice
  # does NOT apply — this firmware exposes no S3 and ZFS rules out hibernation,
  # so s2idle is the only sleep state (see boot.nix).
  #
  # The previous fix reloaded the `thunderbolt` module via
  # `powerManagement.resumeCommands`, but that was a silent no-op: `typec` pins
  # `thunderbolt` (lsmod: `thunderbolt ... 1 typec`), so `modprobe -r thunderbolt`
  # fails "in use" and the old `|| true` swallowed it. It also ran in `preStop` of
  # `sleep-actions` with no ordering against `systemd-suspend.service`.
  #
  # Instead, `tb-redock` (ordered After=systemd-suspend.service, i.e. on resume)
  # rebuilds tunnels surgically: it deauthorizes->reauthorizes the dock device
  # (`echo 0 then 1 > .../authorized`, supported since the domain reports
  # `deauthorization=1`), and only if USB devices don't come back does it escalate
  # to unbinding/rebinding the dock's NHI PCI function — re-probing just that one
  # USB4 domain (the replug equivalent) without touching the typec-pinned module.
  # All steps log under `journalctl -u tb-redock.service` with a `[tb-redock]` tag.
  systemd.services.tb-redock = {
    description = "Rebuild Thunderbolt dock tunnels after s2idle resume";
    after = [ "systemd-suspend.service" ];
    wantedBy = [ "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${tbRedock}";
    };
  };

  # TLP is configured in ./framework-tlp-advanced.nix; keep PPD off to avoid overlap
  services.power-profiles-daemon.enable = false;
  services.tlp.enable = true;

  # Leave CPU scaling to TLP to avoid duelling tuners
  services.auto-cpufreq.enable = false;
}
