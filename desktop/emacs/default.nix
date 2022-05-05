{ config, pkgs, ... }:

{
  # home.file.".emacs.d/init.el".source = ./init.el;

  programs.emacs = {
    enable = true;
    package = pkgs.emacs;
  };
}
