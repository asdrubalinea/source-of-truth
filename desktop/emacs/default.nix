{ config, pkgs, ... }:

{
  home.file.".doom.d" = {
    recursive = true;
    source = ./.doom.d;
  };

  programs.emacs = {
    enable = true;
    extraPackages = epkgs: [ epkgs.vterm ];
  };
}
