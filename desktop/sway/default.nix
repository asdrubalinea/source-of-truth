{ pkgs, config, ... }:

{
  wayland.windowManager.sway = {
    enable = true;
    package = pkgs.sway;
    wrapperFeatures.gtk = true;

    # TODO: convert config into Nix lang
    config = null;
    # config = {
    # startup = [
    # { command = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"; always = true; }
    # ];
    # };

    extraConfig = (builtins.readFile ./sway/config)
      + "exec_always ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
      + "exec ${pkgs.wlsunset} -l 45.27 -L 9.09";
  };

  xdg.configFile."waybar" = {
    source = ./waybar;
    recursive = true;
  };

  home.file.".wallpaper".source = ./wallpaper;

  home.packages = with pkgs; [
    waybar
    swaylock
    swayidle
    wl-clipboard
    mako
    bemenu
    wlsunset

    # TODO: activate theme
    # https://discourse.nixos.org/t/some-lose-ends-for-sway-on-nixos-which-we-should-fix/17728/2
    dracula-theme
  ];
}
