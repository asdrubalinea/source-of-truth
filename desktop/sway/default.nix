{ pkgs, config, ... }:

{
  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;

    config = null;
    extraConfig = builtins.readFile ./sway/config;
  };

  xdg.configFile."waybar" = {
    source = ./waybar;
    recursive = true;
  };

  home.packages = with pkgs; [
    swaylock
    swayidle
    wl-clipboard
    mako # notification daemon
    alacritty # Alacritty is the default terminal in the config
    bemenu
    waybar
    wlsunset
  ];
}
