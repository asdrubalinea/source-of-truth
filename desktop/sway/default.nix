{ pkgs, config, ... }:

{
  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;

    # TODO: convert config into Nix lang
    config = null;
    # config = {
      # startup = [
        # { command = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"; always = true; }
      # ];
    # };

    extraConfig = (builtins.readFile ./sway/config) + "exec_always ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
  };

  xdg.configFile."waybar" = {
    source = ./waybar;
    recursive = true;
  };

  home.file.".wallpaper".source = ./wallpaper;

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
