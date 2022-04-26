{ config, pkgs, ... }:

{
  home.file.".emacs.d/init.el".source = ./init.el;
  home.packages = with pkgs; [ emacs ];
}
