{ pkgs, ... }:

let
  myEmacs = pkgs.emacsWithPackagesFromUsePackage {
    package = pkgs.emacs-pgtk;
    config = ./init.el;
    defaultInitFile = false;
    alwaysEnsure = true;
    extraEmacsPackages = epkgs: with epkgs; [
      use-package
      treesit-grammars.with-all-grammars
      vterm
      pdf-tools
    ];
  };
in
{
  home.packages = [ myEmacs ];

  # ~/.emacs.d/ already exists (eln-cache, auto-save-list), which makes Emacs
  # pick that as user-emacs-directory and ignore XDG.  Drop the init files
  # there so they're actually loaded.
  home.file.".emacs.d/early-init.el".source = ./early-init.el;
  home.file.".emacs.d/init.el".source = ./init.el;

  services.emacs = {
    enable = true;
    package = myEmacs;
    client.enable = true;
    socketActivation.enable = true;
  };
}
