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
    # claude-code-ide isn't on MELPA, so build it from a pinned upstream rev.
    # Goes through `override` (not `extraEmacsPackages`) because the
    # use-package parser resolves names against `epkgs.<name>` directly — a
    # `melpaBuild` injected here makes `epkgs.claude-code-ide` resolve.
    override = self: super: {
      claude-code-ide = self.melpaBuild {
        pname = "claude-code-ide";
        version = "0-unstable-2026-04-02";
        src = pkgs.fetchFromGitHub {
          owner = "manzaltu";
          repo = "claude-code-ide.el";
          rev = "56db02ee386d009ddb8b1482310f1f9beeefb810";
          hash = "sha256-qH1QnG5G+0UiH/v0KaS7oSpQZY+BkUMZvrjbx6kyFhg=";
        };
        packageRequires = [ self.transient self.websocket self.web-server ];
        recipe = pkgs.writeText "claude-code-ide-recipe" ''
          (claude-code-ide :fetcher github :repo "manzaltu/claude-code-ide.el")
        '';
      };
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
