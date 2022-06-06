{ pkgs, config, ... }:

let
  # cfg = config.xsession.windowManager.awesome;
  wallpaper = "${config.xdg.configHome}/wallpaper";
in
{
  xsession.windowManager.xmonad = {
    enable = true;
    enableContribAndExtras = true;
    extraPackages = haskellPackages: [
      haskellPackages.dbus
      haskellPackages.List
      haskellPackages.monad-logger
      haskellPackages.xmonad
    ];
  };

  #xdg.configFile."wallpaper".source = ./wallpaper;

  home.packages = with pkgs; [
    # mako # notification daemon
    xmobar
    polybar
    haskellPackages.haskell-language-server
    haskellPackages.hoogle
    cabal-install
    stack
  ];
}
