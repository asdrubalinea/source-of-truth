{ lib, hostname, ... }: {
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings = lib.importJSON ./config.jsonc;
    style = builtins.readFile ./style.css;
  };
}
