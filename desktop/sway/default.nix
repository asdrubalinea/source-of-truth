{ pkgs, config, ... }:

let
  screen-toggle = pkgs.writeScriptBin "screen-toggle" ''
    #!${pkgs.stdenv.shell}
    read lcd < /tmp/lcd

    if [ "$lcd" -eq "0" ]; then
      swaymsg "output * dpms on"
      echo 1 > /tmp/lcd
    else
      swaymsg "output * dpms off"
      echo 0 > /tmp/lcd
    fi
  '';
in {

  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraOptions = [ "--unsupported-gpu" ];

    # TODO: convert config into Nix lang
    config = null;
    # config = {
    # startup = [
    # {
    # command =
    # "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
    # always = true;
    # }
    # {
    # command = "${pkgs.wlsunset}/bin/wlsunset -l 45.27 -L 9.09";
    # always = false;
    # }
    # ];
    # };

    extraConfig = (builtins.readFile ./sway/config) + ''
      bindsym XF86Calculator exec ${screen-toggle}/bin/screen-toggle

      exec_always ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
      exec ${pkgs.wlsunset}/bin/wlsunset -l 45.27 -L 9.09
      exec ${pkgs.mako}/bin/mako
    '';
  };

  xdg.configFile."waybar" = {
    source = ./waybar;
    recursive = true;
  };

  xdg.configFile."rofi" = {
    source = ./rofi;
    recursive = true;
  };

  home.file.".wallpaper".source = ./wallpaper;

  home.packages = with pkgs; [
    waybar
    swaylock
    swayidle
    wl-clipboard
    mako
    rofi-wayland
    wlsunset
    grim

    screen-toggle

    # TODO: activate theme
    # https://discourse.nixos.org/t/some-lose-ends-for-sway-on-nixos-which-we-should-fix/17728/2
    dracula-theme
  ];
}
