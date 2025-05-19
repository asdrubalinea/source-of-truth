{ pkgs, ... }:
{
  systemd.services.disable-fingerprint-led = {
    description = "Disable Framework Laptop Fingerprint LED at boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      ExecStart = "${pkgs.fw-ectool}/bin/ectool led power off";
    };
  };

  systemd.services.set-default-brightness = {
    description = "Set default brightness level";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      ExecStart = "${pkgs.brightnessctl}/bin/brightnessctl set 30%";
    };
  };
}
