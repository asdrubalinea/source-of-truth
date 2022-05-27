{ pkgs, config, ... }:

let
  cfg = config.xsession.windowManager.awesome;
  wallpaper = "${config.xdg.configHome}/wallpaper";
in
{
  xsession.windowManager.awesome = {
    enable = true;
    luaModules = with pkgs.luaPackages; [
      luarocks # is the package manager for Lua modules
    ];
  };

  #xdg.configFile."wallpaper".source = ./wallpaper;

  home.packages = with pkgs; [
    # mako # notification daemon
  ];
}
