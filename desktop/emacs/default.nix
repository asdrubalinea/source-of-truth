{ config, pkgs, ... }:

{
  programs.emacs = {
    enable = true;
    extraPackages = epkgs: [ epkgs.vterm ];
    # extraConfig = builtins.readFile ./init.el;
  };
}
