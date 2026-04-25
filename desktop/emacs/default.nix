{ pkgs, ... }:

let
  myEmacs = pkgs.emacsWithPackagesFromUsePackage {
    package = pkgs.emacs-pgtk;
    config = ./init.el;
    defaultInitFile = true;
    alwaysEnsure = true;
  };
in
{
  home.packages = [ myEmacs ];
}
