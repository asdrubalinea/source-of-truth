{ pkgs, config, ... }:
let
  setWallpaper = pkgs.writeShellScript "awww-set-wallpaper" ''
    until ${pkgs.awww}/bin/awww query >/dev/null 2>&1; do
      sleep 0.1
    done
    exec ${pkgs.awww}/bin/awww img ${config.home.homeDirectory}/.wallpaper
  '';
in
{
  home.file.".wallpaper".source = ./wallpaper3345.png;
  home.packages = [ pkgs.awww ];

  systemd.user.services.awww-daemon = {
    Unit = {
      Description = "awww wallpaper daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${pkgs.awww}/bin/awww-daemon";
      ExecStartPost = "${setWallpaper}";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
