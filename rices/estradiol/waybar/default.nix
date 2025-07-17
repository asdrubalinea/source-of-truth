{ lib, hostname, ... }: {
  programs.waybar = {
    enable = hostname != "tempest";
    settings = lib.importJSON ./config.jsonc;
    style = builtins.readFile ./style.css;
  };
}
