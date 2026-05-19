{ pkgs, ... }:
{
  home.packages = [ pkgs.swaylock-effects ];

  services.swayidle = {
    enable = true;
    systemdTargets = [ "graphical-session.target" ];
    timeouts = [
      {
        timeout = 300;
        command = "${pkgs.systemd}/bin/loginctl lock-session";
      }
      {
        timeout = 600;
        command = "${pkgs.niri-unstable}/bin/niri msg action power-off-monitors";
        resumeCommand = "${pkgs.niri-unstable}/bin/niri msg action power-on-monitors";
      }
    ];
    events = [
      {
        event = "before-sleep";
        command = "${pkgs.systemd}/bin/loginctl lock-session";
      }
      {
        event = "lock";
        command = "${pkgs.swaylock-effects}/bin/swaylock -f";
      }
    ];
  };
}
