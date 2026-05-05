{ pkgs, ... }:

let
  # The parser in `emacsWithPackagesFromUsePackage` reads a single source for
  # `(use-package ...)' decls — it doesn't follow runtime `(load ...)' calls.
  # Concatenate init.el + every lisp/*.el so the parser sees every package
  # that any module declares. The on-disk delivery below stays split into
  # separate files; this concat exists only at flake-eval time.
  elispModules = [
    ./init.el
    ./lisp/ui.el
    ./lisp/editor.el
    ./lisp/completion.el
    ./lisp/code.el
    ./lisp/project.el
    ./lisp/tools.el
    ./lisp/mail.el
    ./lisp/keys.el
  ];
  parserConfig = pkgs.writeText "init-concat.el"
    (builtins.concatStringsSep "\n" (map builtins.readFile elispModules));

  myEmacs = pkgs.emacsWithPackagesFromUsePackage {
    package = pkgs.emacs-pgtk;
    config = parserConfig;
    defaultInitFile = false;
    # Parse-time: install every use-package'd package unless it has :ensure nil.
    # Runtime: init.el sets `use-package-always-ensure nil` so Emacs never
    # tries to install at startup — packages come from this Nix wrapper.
    alwaysEnsure = true;
    # MELPA's `claude-code` recipe points at yuya373/claude-code-emacs
    # (multi-file, vterm + projectile only). We want stevemolitor/claude-code.el
    # (single-file, exposes `claude-code-terminal-backend` for eat). Has to go
    # through `override` rather than `extraEmacsPackages`: the use-package
    # parser pulls `epkgs.claude-code` directly, so an overrideScope is the
    # only way to make that lookup return the swapped derivation.
    override = self: super: {
      claude-code = super.claude-code.overrideAttrs (_: {
        version = "0.4.5-unstable-2026-04-30";
        src = pkgs.fetchFromGitHub {
          owner = "stevemolitor";
          repo = "claude-code.el";
          rev = "03199df8b3a1e9cd4857f0851f7a912ba524aff3";
          hash = "sha256-5QJrWIu4EgnHcOqMwlrs2JBBx7aI9OaSJswesr6Apfk=";
        };
        propagatedBuildInputs = [ self.transient self.inheritenv ];
        propagatedUserEnvPkgs = [ self.transient self.inheritenv ];
      });
    };
    extraEmacsPackages = epkgs: with epkgs; [
      use-package
      treesit-grammars.with-all-grammars
      vterm
      compile-angel
      benchmark-init
      # Provided as a manual emacs package in nixpkgs (the elisp ships as
      # the `mu4e` output of `pkgs.mu`, but `epkgs.mu4e` already wraps it
      # properly for the load-path). `(use-package mu4e :ensure nil)' in
      # init.el resolves against this.
      mu4e
      # Manual-package in nixpkgs: builds the native ghostel-module.so with
      # zig at flake-eval time, so `M-x ghostel` doesn't try to download or
      # compile a module at runtime.
      ghostel
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
  home.file.".emacs.d/lisp" = {
    source = ./lisp;
    recursive = true;
    onChange = "rm -f $HOME/.emacs.d/lisp/*.elc";
  };

  services.emacs = {
    enable = true;
    package = myEmacs;
    client.enable = true;
    socketActivation.enable = true;
  };
}
