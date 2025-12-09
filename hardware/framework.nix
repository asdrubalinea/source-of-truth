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

    logind.settings.Login = {
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandlePowerKey = "hibernate";
    };

    # Enable thermal management to prevent overheating
    thermald.enable = true;

    # Enable TRIM for SSD health
    fstrim.enable = true;
  };

  # TLP is configured in ./framework-tlp-advanced.nix; keep PPD off to avoid overlap
  services.power-profiles-daemon.enable = false;
  services.tlp.enable = true;

  # Leave CPU scaling to TLP to avoid duelling tuners
  services.auto-cpufreq.enable = false;
}
