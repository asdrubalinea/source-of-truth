{ pkgs, ... }:

let
  myEmacs = pkgs.emacsWithPackagesFromUsePackage {
    package = pkgs.emacs-pgtk;
    config = ./init.el;
    defaultInitFile = false;
    # Parse-time: install every use-package'd package unless it has :ensure nil.
    # Runtime: init.el sets `use-package-always-ensure nil` so Emacs never
    # tries to install at startup — packages come from this Nix wrapper.
    alwaysEnsure = true;
    extraEmacsPackages = epkgs: with epkgs; [
      use-package
      treesit-grammars.with-all-grammars
      vterm
      compile-angel
      benchmark-init
    ];
  };
in
{
  home.packages = [ myEmacs ];

  # ~/.emacs.d/ already exists (eln-cache, auto-save-list), which makes Emacs
  # pick that as user-emacs-directory and ignore XDG.  Drop the init files
  # there so they're actually loaded.
  #
  # onChange wipes any stale .elc — nix store sources have mtime 1970, so a
  # locally-compiled .elc always looks "newer" to load-prefer-newer and
  # shadows the symlinked source until removed.
  home.file.".emacs.d/early-init.el" = {
    source = ./early-init.el;
    onChange = "rm -f $HOME/.emacs.d/early-init.elc";
  };
  home.file.".emacs.d/init.el" = {
    source = ./init.el;
    onChange = "rm -f $HOME/.emacs.d/init.elc";
  };

  services.emacs = {
    enable = true;
    package = myEmacs;
    client.enable = true;
    socketActivation.enable = true;
  };
}
