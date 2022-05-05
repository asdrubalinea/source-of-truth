{ config, pkgs, ... }:

{
  # TODO: add Doom Emacs private config here
  # home.file.".emacs.d/init.el".source = ./init.el;

  programs.emacs = {
    enable = true;
    package = pkgs.emacs;

    extraPackages = epkgs: [ epkgs.vterm ];
  };
}
