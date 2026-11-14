{pkgs, ...}:
# Machine policy: under mango, orchid's wallpaper is a live web page drawn over
# Noctalia's static one. niri is untouched — the unit hangs off mango-session.target.
let
  webWallpaper = pkgs.callPackage ../../packages/web-wallpaper.nix {};
  viceCountdown = pkgs.callPackage ../../packages/vice-countdown.nix {};
in {
  systemd.user.services.web-wallpaper = {
    Unit = {
      Description = "Web page as the mango wallpaper";
      PartOf = ["mango-session.target"];
      After = ["mango-session.target"];
    };
    Service = {
      ExecStart = "${webWallpaper}/bin/web-wallpaper file://${viceCountdown}/index.html";
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = ["mango-session.target"];
  };
}
