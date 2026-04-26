;;; init.el --- -*- lexical-binding: t; -*-

;; Packages are installed by Nix via emacsWithPackagesFromUsePackage,
;; which parses the (use-package ...) declarations below at flake-eval
;; time.  Built-in packages use :ensure nil so the parser skips them.

(eval-when-compile (require 'use-package))

(setq use-package-always-defer t
      use-package-always-ensure nil
      use-package-expand-minimally t)

;;; Core defaults --------------------------------------------------------------

(setopt
 use-short-answers t
 confirm-kill-emacs #'yes-or-no-p
 sentence-end-double-space nil
 fill-column 100
 require-final-newline t
 vc-follow-symlinks t
 create-lockfiles nil
 make-backup-files nil
 ring-bell-function 'ignore
 read-process-output-max (* 4 1024 1024)
 process-adaptive-read-buffering nil
 inhibit-compacting-font-caches t
 redisplay-skip-fontification-on-input t
 fast-but-imprecise-scrolling t
 jit-lock-defer-time 0
 bidi-inhibit-bpa t)

(setq-default indent-tabs-mode nil
              tab-width 2
              bidi-display-reordering 'left-to-right
              bidi-paragraph-direction 'left-to-right)

(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode 1)

(global-auto-revert-mode 1)
(savehist-mode 1)
(save-place-mode 1)
(recentf-mode 1)
(delete-selection-mode 1)
(electric-pair-mode 1)
(repeat-mode 1)
(global-so-long-mode 1)
(pixel-scroll-precision-mode 1)
;; Touchpad keeps pixel-precision (smooth glide); discrete mouse-wheel events
;; skip interpolation and fall through to plain `mouse-wheel-scroll-amount'.
(setq pixel-scroll-precision-interpolate-mice nil)

;; Mouse wheel: one notch = one line, no progressive acceleration on fast spins.
(setq mouse-wheel-scroll-amount '(1 ((shift) . hscroll) ((control) . text-scale))
      mouse-wheel-progressive-speed nil
      mouse-wheel-follow-mouse t)

(when (fboundp 'which-key-mode) (which-key-mode 1))

;;; Theme ----------------------------------------------------------------------
;; Themes are loaded lazily — only `load-theme` (or `consult-theme` at SPC t t)
;; pulls a given theme in.  Settings below tune each family in case it's picked.

(setq modus-themes-italic-constructs t
      modus-themes-bold-constructs t
      modus-themes-mixed-fonts t
      modus-themes-org-blocks 'gray-background)

(use-package ef-themes
  :defer t
  :custom
  (ef-themes-mixed-fonts t)
  (ef-themes-variable-pitch-ui t))

(use-package doom-themes
  :defer t
  :custom
  (doom-themes-enable-bold t)
  (doom-themes-enable-italic t)
  :config
  (doom-themes-org-config))

(load-theme 'modus-vivendi-tinted t)

;;; UI polish ------------------------------------------------------------------

(use-package nerd-icons
  :demand t
  :custom (nerd-icons-font-family "Symbols Nerd Font Mono"))

(use-package nerd-icons-completion
  :after marginalia
  :config (nerd-icons-completion-mode)
  :hook (marginalia-mode . nerd-icons-completion-marginalia-setup))

(use-package nerd-icons-corfu
  :after corfu
  :config (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))

(use-package nerd-icons-dired
  :hook (dired-mode . nerd-icons-dired-mode))

(use-package doom-modeline
  :init (doom-modeline-mode 1)
  :custom
  (doom-modeline-height 28)
  (doom-modeline-icon t)
  (doom-modeline-buffer-encoding nil)
  (doom-modeline-minor-modes nil)
  (doom-modeline-bar-width 4))

(use-package breadcrumb
  :hook ((prog-mode . breadcrumb-local-mode)
         (text-mode . breadcrumb-local-mode)))

(use-package indent-bars
  :hook (prog-mode . indent-bars-mode)
  :custom
  (indent-bars-color '(highlight :face-bg t :blend 0.2))
  (indent-bars-pattern ".")
  (indent-bars-width-frac 0.15)
  (indent-bars-pad-frac 0.1)
  (indent-bars-zigzag nil)
  (indent-bars-color-by-depth nil)
  (indent-bars-highlight-current-depth '(:blend 0.4))
  (indent-bars-display-on-blank-lines nil))

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package hl-todo
  :hook (prog-mode . hl-todo-mode)
  :custom
  (hl-todo-keyword-faces
   '(("TODO"  . "#fabd2f")
     ("FIXME" . "#fb4934")
     ("HACK"  . "#fe8019")
     ("NOTE"  . "#83a598")
     ("XXX"   . "#fb4934"))))

(use-package diff-hl
  :hook ((prog-mode . diff-hl-mode)
         (magit-pre-refresh . diff-hl-magit-pre-refresh)
         (magit-post-refresh . diff-hl-magit-post-refresh))
  :config (diff-hl-flydiff-mode 1))

;; Workflow is one frame per project, tiled by niri — no in-Emacs tab-bar.
;; Frame title carries the project name so niri window-rules can match on it.
(setq frame-title-format
      '((:eval (or (frame-parameter nil 'name)
                   (when-let* ((p (project-current))) (project-name p))
                   (buffer-name)))))

;;; Hand off post-startup GC to gcmh ------------------------------------------

(use-package gcmh
  :demand t
  :config
  (setq gcmh-idle-delay 'auto
        gcmh-auto-idle-delay-factor 10
        gcmh-high-cons-threshold (* 32 1024 1024))
  (gcmh-mode 1))

;;; Keep state out of ~/.config/emacs ------------------------------------------

(use-package no-littering
  :demand t
  :config
  (no-littering-theme-backups)
  (setq custom-file (no-littering-expand-etc-file-name "custom.el"))
  (when (file-exists-p custom-file) (load custom-file 'noerror)))

;;; Fonts ----------------------------------------------------------------------

(use-package fontaine
  :demand t
  :config
  (setq fontaine-presets
        '((regular :default-family "Maple Mono" :default-height 150
                   :variable-pitch-family "Inter")
          (large   :default-family "Maple Mono" :default-height 180
                   :variable-pitch-family "Inter")
          (presentation :default-family "Maple Mono" :default-height 220
                        :variable-pitch-family "Inter")))
  (fontaine-mode 1)
  (fontaine-set-preset 'regular)
  (set-fontset-font t 'emoji
                    (font-spec :family "Noto Color Emoji") nil 'append)
  (set-fontset-font t 'symbol
                    (font-spec :family "Symbols Nerd Font Mono") nil 'append))

;;; Modal editing --------------------------------------------------------------

(use-package evil
  :demand t
  :init
  (setq evil-want-C-u-scroll t
        evil-want-keybinding nil
        evil-undo-system 'undo-redo)
  :config
  (evil-mode 1))

(use-package evil-collection
  :after evil
  :demand t
  :config (evil-collection-init))

(use-package evil-surround
  :after evil
  :config (global-evil-surround-mode 1))

(use-package evil-commentary
  :after evil
  :config (evil-commentary-mode 1))

;;; Wayland clipboard fallback -------------------------------------------------

(when (and (eq window-system 'pgtk)
           (executable-find "wl-copy"))
  (setq interprogram-cut-function
        (lambda (text)
          (with-temp-buffer
            (insert text)
            (call-process-region (point-min) (point-max) "wl-copy"))))
  (setq interprogram-paste-function
        (lambda ()
          (let ((s (shell-command-to-string "wl-paste -n 2>/dev/null")))
            (and (not (string-empty-p s)) s)))))

;;; Completion stack -----------------------------------------------------------

(use-package vertico
  :init (vertico-mode)
  :custom (vertico-cycle t))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides
   '((file (styles basic partial-completion)))))

(use-package marginalia
  :init (marginalia-mode))

(use-package consult
  :bind (("C-s"   . consult-line)
         ("C-x b" . consult-buffer)
         ("M-y"   . consult-yank-pop)
         ("M-g g" . consult-goto-line)
         ("M-s r" . consult-ripgrep)))

(use-package embark
  :bind (("C-." . embark-act)
         ("C-;" . embark-dwim)))

(use-package embark-consult
  :after (embark consult))

(use-package corfu
  :init (global-corfu-mode)
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.1)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  (corfu-popupinfo-delay '(0.3 . 0.1)))

(use-package corfu-popupinfo
  :ensure nil
  :after corfu
  :hook (corfu-mode . corfu-popupinfo-mode))

(use-package cape
  :init
  (add-hook 'completion-at-point-functions #'cape-dabbrev)
  (add-hook 'completion-at-point-functions #'cape-file))

(use-package kind-icon
  :after corfu
  :custom (kind-icon-default-face 'corfu-default)
  :config
  (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))

(use-package which-key
  :init (which-key-mode 1)
  :custom
  (which-key-idle-delay 0.3)
  (which-key-idle-secondary-delay 0.05))

;;; Snippets ------------------------------------------------------------------

(use-package yasnippet
  :defer 1
  :config (yas-global-mode 1))

(use-package yasnippet-snippets
  :after yasnippet)

(use-package consult-yasnippet
  :after (consult yasnippet))

;;; Tree-sitter ----------------------------------------------------------------

(use-package treesit
  :ensure nil
  :config
  (setq treesit-font-lock-level 4)
  (dolist (m '((python-mode . python-ts-mode)
               (c-mode . c-ts-mode)
               (c++-mode . c++-ts-mode)
               (rust-mode . rust-ts-mode)
               (js-mode . js-ts-mode)
               (typescript-mode . typescript-ts-mode)
               (go-mode . go-ts-mode)
               (yaml-mode . yaml-ts-mode)
               (json-mode . json-ts-mode)
               (bash-mode . bash-ts-mode)
               (php-mode . php-ts-mode)))
    (add-to-list 'major-mode-remap-alist m)))

(use-package treesit-auto
  :demand t
  :custom (treesit-auto-install nil)
  :config (global-treesit-auto-mode))

;;; LSP / diagnostics / docs ---------------------------------------------------

(use-package eglot
  :ensure nil
  :hook ((python-ts-mode rust-ts-mode go-ts-mode
          c-ts-mode c++-ts-mode tsx-ts-mode typescript-ts-mode
          nix-mode typst-ts-mode
          php-ts-mode vue-mode) . eglot-ensure)
  :custom
  (eglot-autoshutdown t)
  (eglot-events-buffer-size 0)
  (eglot-sync-connect 0)
  (eglot-extend-to-xref t)
  :config
  (fset #'jsonrpc--log-event #'ignore)
  (add-to-list 'eglot-server-programs '(nix-mode . ("nil")))
  (add-to-list 'eglot-server-programs '(typst-ts-mode . ("tinymist")))
  (add-to-list 'eglot-server-programs
               '(php-ts-mode . ("phpactor" "language-server")))
  (add-to-list 'eglot-server-programs
               '(vue-mode . ("vue-language-server" "--stdio"))))

(use-package flymake
  :ensure nil
  :hook (prog-mode . flymake-mode)
  :custom (flymake-no-changes-timeout 0.5))

(use-package eldoc
  :ensure nil
  :custom
  (eldoc-echo-area-use-multiline-p nil)
  (eldoc-idle-delay 0.2))

(use-package apheleia
  :init (apheleia-global-mode 1))

;;; Help & docs ---------------------------------------------------------------

(use-package eldoc-box
  :hook (eglot-managed-mode . eldoc-box-hover-at-point-mode)
  :custom
  (eldoc-box-max-pixel-width 600)
  (eldoc-box-max-pixel-height 400))

(use-package helpful
  :bind (("C-h f" . helpful-callable)
         ("C-h v" . helpful-variable)
         ("C-h k" . helpful-key)
         ("C-h x" . helpful-command)
         ("C-c C-d" . helpful-at-point)))

(use-package vundo
  :bind ("C-x u" . vundo)
  :custom (vundo-glyph-alist vundo-unicode-symbols))

;;; Language modes -------------------------------------------------------------

(use-package nix-mode
  :mode "\\.nix\\'")

(use-package typst-ts-mode
  :mode ("\\.typ\\'" . typst-ts-mode))

(use-package web-mode
  :mode (("\\.html?\\'" . web-mode)
         ("\\.blade\\.php\\'" . web-mode))
  :custom
  (web-mode-markup-indent-offset 2)
  (web-mode-css-indent-offset 2)
  (web-mode-code-indent-offset 2)
  (web-mode-enable-auto-pairing t)
  (web-mode-enable-auto-quoting nil)
  (web-mode-enable-current-element-highlight t)
  :config
  (define-derived-mode vue-mode web-mode "Vue"
    "Major mode for Vue single-file components.")
  (add-to-list 'auto-mode-alist '("\\.vue\\'" . vue-mode)))

;;; Project & workspace -------------------------------------------------------

(use-package envrc
  :hook (after-init . envrc-global-mode))

(use-package beframe
  :demand t
  :custom
  (beframe-functions-in-frames '(clone-frame))
  (beframe-global-buffers '("*scratch*" "*Messages*" "*Backtrace*" "*claude-*"))
  :config
  (beframe-mode 1)
  ;; Make consult-buffer respect beframe's per-frame scope.
  (with-eval-after-load 'consult
    (defvar beframe-consult-source
      `(:name "Frame buffers"
        :narrow ?F
        :category buffer
        :face beframe-face
        :history beframe-history
        :items ,#'beframe-buffer-names
        :action ,#'switch-to-buffer
        :state ,#'consult--buffer-state))
    (add-to-list 'consult-buffer-sources 'beframe-consult-source)))

(use-package dired-sidebar
  :commands (dired-sidebar-toggle-sidebar dired-sidebar-show-sidebar)
  :hook ((server-after-make-frame . dired-sidebar-show-sidebar)
         (window-setup . dired-sidebar-show-sidebar))
  :custom
  (dired-sidebar-theme 'nerd-icons)
  (dired-sidebar-use-term-integration t)
  (dired-sidebar-use-custom-modeline nil)
  (dired-sidebar-should-follow-file t)
  (dired-sidebar-width 32))

(use-package project
  :ensure nil
  :custom
  (project-vc-extra-root-markers '(".project" ".git"))
  (project-switch-commands #'project-dired)
  :config
  (defun my/project-switch-in-new-frame ()
    "Pick a project and open it in a new frame named after the project."
    (interactive)
    (let* ((dir (project-prompt-project-dir))
           (name (file-name-nondirectory (directory-file-name dir))))
      (select-frame (make-frame `((name . ,name))))
      (let ((default-directory dir))
        (project-switch-project dir)))))

;;; Magit ----------------------------------------------------------------------

(use-package transient :defer t)

(use-package magit
  :defer t
  :bind (("C-x g" . magit-status))
  :custom
  (magit-diff-refine-hunk t)
  (magit-save-repository-buffers 'dontask)
  (magit-process-finish-apply-ansi-colors t))

(use-package forge
  :after magit)

;;; AI assistant --------------------------------------------------------------

(use-package claude-code
  :defer t
  :commands (claude-code-run claude-code-transient claude-code-send-region
             claude-code-switch-to-buffer claude-code-quit
             claude-code-insert-current-file-path-to-session
             claude-code-open-prompt-file)
  :init
  ;; Package autoloads point at subfiles (claude-code-core, -ui, ...) which
  ;; don't (require 'vterm); only the umbrella claude-code.el does. Without
  ;; this hook, claude-code-vterm-mode's parent vterm-mode is undefined and
  ;; calls fail with "void function: vterm-mode".
  (with-eval-after-load 'claude-code-core (require 'claude-code))
  ;; claude-code-run uses (projectile-project-root), which returns nil in
  ;; buffers with no project (e.g. *scratch*) → get-buffer-create chokes on
  ;; "Wrong type argument: stringp, nil". Fall back to project.el or pwd.
  (with-eval-after-load 'projectile
    (define-advice projectile-project-root
        (:around (orig &rest args) my/fallback-to-project-or-pwd)
      (or (apply orig args)
          (when-let ((p (project-current))) (project-root p))
          default-directory))))

;;; Terminal -------------------------------------------------------------------

(use-package vterm
  :defer t
  :commands vterm
  :custom
  (vterm-max-scrollback 100000)
  (vterm-timer-delay 0.01))

;;; Org ------------------------------------------------------------------------

(use-package org
  :defer t
  :hook ((org-mode . org-indent-mode)
         (org-mode . variable-pitch-mode)
         (org-mode . visual-line-mode))
  :custom
  (org-directory "~/org")
  (org-startup-folded 'content)
  (org-hide-emphasis-markers t)
  (org-pretty-entities t)
  (org-src-fontify-natively t)
  (org-src-tab-acts-natively t)
  (org-fontify-quote-and-verse-blocks t)
  (org-auto-align-tags nil)
  (org-tags-column 0)
  (org-special-ctrl-a/e t)
  (org-insert-heading-respect-content t)
  (org-cycle-separator-lines 2))

(use-package org-modern
  :after org
  :hook ((org-mode . org-modern-mode)
         (org-agenda-finalize . org-modern-agenda)))

(use-package org-appear
  :hook (org-mode . org-appear-mode))

(use-package org-roam
  :defer t
  :custom (org-roam-directory "~/org/roam")
  :config (org-roam-db-autosync-mode 1))

;;; LaTeX / AUCTeX / pdf-tools -------------------------------------------------

(use-package auctex
  :defer t
  :hook ((LaTeX-mode . prettify-symbols-mode)
         (LaTeX-mode . turn-on-reftex)
         (LaTeX-mode . eglot-ensure))
  :custom
  (TeX-auto-save t)
  (TeX-parse-self t)
  (TeX-master nil)
  (TeX-PDF-mode t)
  (TeX-source-correlate-mode t)
  (TeX-source-correlate-method 'synctex)
  (TeX-source-correlate-start-server t)
  (TeX-view-program-selection '((output-pdf "Zathura"))))

(use-package cdlatex
  :hook ((LaTeX-mode . turn-on-cdlatex)
         (org-mode . turn-on-org-cdlatex)))

(use-package pdf-tools
  :defer t
  :magic ("%PDF" . pdf-view-mode)
  :config (pdf-tools-install :no-query))

;;; Leader keybindings --------------------------------------------------------

(use-package general
  :demand t
  :after evil
  :config
  (general-evil-setup t)
  (general-create-definer my/leader
    :states '(normal visual motion emacs)
    :keymaps 'override
    :prefix "SPC"
    :prefix-map 'my/leader-map
    :non-normal-prefix "M-SPC")

  (defun my/show-leader-bindings ()
    "Pop up a tall right-side help buffer listing all SPC leader bindings.
The buffer is a regular `help-mode' buffer: scroll with C-v / M-v,
search with `/' (evil) or C-s, dismiss with q."
    (interactive)
    (let ((display-buffer-alist
           (cons '("\\*Help\\*\\'"
                   (display-buffer-in-side-window)
                   (side . right)
                   (slot . 0)
                   (window-width . 0.4)
                   (preserve-size . (t . nil)))
                 display-buffer-alist)))
      (describe-keymap my/leader-map)))

  (my/leader
    "SPC" '(project-find-file       :wk "find file in project")
    "?"   '(my/show-leader-bindings :wk "show leader bindings")
    "."   '(find-file               :wk "find file")
    ","   '(consult-buffer          :wk "switch buffer")
    "/"   '(consult-ripgrep         :wk "search project")
    ";"   '(execute-extended-command :wk "M-x")
    ":"   '(eval-expression         :wk "eval-expression")
    "x"   '(scratch-buffer          :wk "scratch")

    "b"   '(:ignore t :wk "buffer")
    "b b" '(consult-buffer          :wk "switch")
    "b d" '(kill-current-buffer     :wk "kill")
    "b r" '(revert-buffer-quick     :wk "revert")
    "b s" '(save-buffer             :wk "save")

    "f"   '(:ignore t :wk "file")
    "f f" '(find-file               :wk "find")
    "f r" '(consult-recent-file     :wk "recent")
    "f s" '(save-buffer             :wk "save")
    "f p" `(,(lambda () (interactive) (find-file user-init-file)) :wk "init.el")

    "F"   '(:ignore t :wk "frame")
    "F n" '(make-frame-command      :wk "new")
    "F p" '(my/project-switch-in-new-frame :wk "new for project")
    "F t" '(tear-off-window         :wk "tear off window → frame")
    "F d" '(delete-frame            :wk "delete")
    "F o" '(other-frame             :wk "other")
    "F O" '(other-frame-prefix      :wk "next cmd in other frame")
    "F r" '(set-frame-name          :wk "rename")
    "F b" '(beframe-switch-buffer   :wk "switch buf (frame-scoped)")
    "F a" '(beframe-assume-frame-buffers :wk "assume buffers from…")
    "F u" '(beframe-unassume-frame-buffers :wk "unassume buffers")

    "p"   '(:ignore t :wk "project")
    "p p" '(project-switch-project  :wk "switch")
    "p f" '(project-find-file       :wk "find file")
    "p b" '(project-switch-to-buffer :wk "buffer")
    "p d" '(project-dired           :wk "dired")
    "p k" '(project-kill-buffers    :wk "kill buffers")
    "p c" '(project-compile         :wk "compile")
    "p t" '(dired-sidebar-toggle-sidebar :wk "sidebar")

    "g"   '(:ignore t :wk "git")
    "g g" '(magit-status            :wk "status")
    "g b" '(magit-blame             :wk "blame")
    "g l" '(magit-log-buffer-file   :wk "log file")
    "g d" '(magit-diff-buffer-file  :wk "diff file")

    "s"   '(:ignore t :wk "search")
    "s s" '(consult-line            :wk "in buffer")
    "s p" '(consult-ripgrep         :wk "in project")
    "s i" '(consult-imenu           :wk "imenu")
    "s y" '(consult-yasnippet       :wk "snippet")

    ;; Splits inside a frame stay rare in this workflow — niri does the tiling.
    ;; Keep just enough to manage popups (magit, help) and tear them off via SPC F t.
    "w"   '(:ignore t :wk "window")
    "w w" '(other-window            :wk "other")
    "w s" '(split-window-below      :wk "split horiz")
    "w v" '(split-window-right      :wk "split vert")
    "w d" '(delete-window           :wk "delete")
    "w o" '(delete-other-windows    :wk "only")

    "h"   '(:ignore t :wk "help")
    "h f" '(helpful-callable        :wk "function")
    "h v" '(helpful-variable        :wk "variable")
    "h k" '(helpful-key             :wk "key")
    "h m" '(describe-mode           :wk "mode")
    "h ." '(helpful-at-point        :wk "at point")

    "o"   '(:ignore t :wk "open")
    "o t" '(vterm                   :wk "terminal")
    "o d" '(dired-sidebar-toggle-sidebar :wk "sidebar")
    "o m" '(magit-status            :wk "magit")

    "t"   '(:ignore t :wk "toggle")
    "t t" '(consult-theme           :wk "theme")
    "t l" '(display-line-numbers-mode :wk "line numbers")
    "t w" '(visual-line-mode        :wk "wrap")
    "t s" '(flyspell-mode           :wk "spell")

    "a"   '(:ignore t :wk "ai / claude")
    "a a" '(claude-code-transient   :wk "claude menu")
    "a s" '(claude-code-run         :wk "start session")
    "a w" '(claude-code-switch-to-buffer :wk "switch to claude buf")
    "a r" '(claude-code-send-region :wk "send region")
    "a b" '(claude-code-insert-current-file-path-to-session :wk "send file path")
    "a o" '(claude-code-open-prompt-file :wk "open prompt file")
    "a q" '(claude-code-quit        :wk "quit session")

    "c"   '(:ignore t :wk "code")
    "c a" '(eglot-code-actions      :wk "actions")
    "c r" '(eglot-rename            :wk "rename")
    "c f" '(eglot-format            :wk "format")
    "c d" '(xref-find-definitions   :wk "definition")
    "c R" '(xref-find-references    :wk "references")
    "c e" '(consult-flymake         :wk "diagnostics")

    "q"   '(:ignore t :wk "quit")
    "q q" '(save-buffers-kill-emacs :wk "save & quit")
    "q f" '(delete-frame            :wk "frame")))

;;; Startup banner -------------------------------------------------------------

(add-hook 'emacs-startup-hook
          (lambda ()
            (message "Emacs init in %s with %d GCs"
                     (emacs-init-time) gcs-done)))

;;; init.el ends here
