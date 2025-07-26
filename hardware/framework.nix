{ pkgs, ... }:
{
  imports = [
    ./framework-tlp-advanced.nix
  ];

  # Install Framework-specific tools for hardware monitoring
  environment.systemPackages = with pkgs; [
    fw-ectool # Framework EC tool for hardware control and monitoring
    framework-tool # Framework laptop management tool (if available)
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

        ExecStart = "${pkgs.brightnessctl}/bin/brightnessctl set 30%";
      };
    };
  };

  # Services
  services = {
    fwupd = {
      enable = true;
      extraRemotes = [ "lvfs-testing" ];
    };

    logind.lidSwitch = "suspend-then-hibernate";
    logind.lidSwitchExternalPower = "ignore";
    logind.extraConfig = ''
      HandlePowerKey=hibernate
      HandleLidSwitchDocked=ignore
    '';

    # Enable thermal management to prevent overheating
    thermald.enable = true;

    # Enable TRIM for SSD health
    fstrim.enable = true;
  };

  # Power Management Daemon (PPD) - Framework's recommended approach
  services.power-profiles-daemon.enable = true;
  # Explicitly disable conflicting daemons
  services.tlp.enable = false;

  services.auto-cpufreq.enable = true;
}
