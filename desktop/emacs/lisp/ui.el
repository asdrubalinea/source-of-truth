;;; ui.el --- theme, modeline, fonts, visual polish -*- lexical-binding: t; no-byte-compile: t; -*-

;;; Theme ----------------------------------------------------------------------

;; modus-themes ships with Emacs but its lisp library isn't on the default
;; load-path until a modus-* theme is first loaded — `(require 'modus-themes)'
;; fails before that.  Set the customize vars via plain setq (the variables
;; are autoloaded by the theme file itself) and let `load-theme' pull in the
;; library.  Palette overrides apply to every modus variant so `SPC t t'
;; toggling preserves the aesthetic.
(setq modus-themes-italic-constructs t
      modus-themes-bold-constructs t
      modus-themes-mixed-fonts nil
      modus-themes-variable-pitch-ui nil
      modus-themes-common-palette-overrides
      '((fg-paren-match    fg-main)
        (bg-paren-match    bg-cyan-subtle)
        (comment           fg-dim)
        (string            fg-alt)
        (fringe            unspecified)
        (border-mode-line-active   bg-mode-line-active)
        (border-mode-line-inactive bg-mode-line-inactive)))

(load-theme 'modus-vivendi-tinted t)

;;; Frame title & dividers ----------------------------------------------------

;; Workflow is one frame per project, tiled by niri — no in-Emacs tab-bar.
;; Frame title carries the project name so niri window-rules can match on it.
(setq frame-title-format
      '((:eval (or (frame-parameter nil 'name)
                   (when-let* ((p (project-current))) (project-name p))
                   (buffer-name)))))

;; Hairline window dividers — the "Lisp Machine window" feel without the cost.
(setq window-divider-default-right-width 1
      window-divider-default-bottom-width 1
      window-divider-default-places t)
(window-divider-mode 1)

;;; Modeline & gutter ---------------------------------------------------------

(use-package nerd-icons
  :demand t
  :custom (nerd-icons-font-family "Symbols Nerd Font Mono"))

;; nano-modeline 1.x has no global mode; you install per-major-mode functions
;; via hooks. `nano-modeline-position' picks header vs footer placement.
(use-package nano-modeline
  :demand t
  :custom (nano-modeline-position #'nano-modeline-footer)
  :hook ((prog-mode . nano-modeline-prog-mode)
         (text-mode . nano-modeline-text-mode)
         (org-mode  . nano-modeline-org-mode)
         (messages-buffer-mode . nano-modeline-message-mode)))

(use-package diff-hl
  :hook ((prog-mode . diff-hl-mode)
         (magit-pre-refresh . diff-hl-magit-pre-refresh)
         (magit-post-refresh . diff-hl-magit-post-refresh)))

;; Project / file / imenu path in the header line. Imenu is lazy and the
;; refresh is throttled, so this is cheap even in big buffers.
(use-package breadcrumb
  :demand t
  :config (breadcrumb-mode 1))

;;; Fonts ----------------------------------------------------------------------

(use-package fontaine
  :demand t
  :config
  (setq fontaine-presets
        '((regular :default-family "Ioskeley Mono" :default-height 150
                   :variable-pitch-family "Inter")
          (large   :default-family "Ioskeley Mono" :default-height 180
                   :variable-pitch-family "Inter")
          (presentation :default-family "Ioskeley Mono" :default-height 220
                        :variable-pitch-family "Inter")))
  (fontaine-mode 1)
  (fontaine-set-preset 'regular))

;; Fontset extensions live outside fontaine's :config so they don't re-fire
;; on every preset switch / theme reload.
(when (display-graphic-p)
  (set-fontset-font t 'emoji  (font-spec :family "Noto Color Emoji") nil 'append)
  (set-fontset-font t 'symbol (font-spec :family "Symbols Nerd Font Mono") nil 'append))

;;; Lisp Machine aesthetic ----------------------------------------------------

;; Dim parens — Symbolics philosophy: parens are quiet punctuation, the
;; structure lives in the indentation. `paren-face' adds a `parenthesis'
;; face that the modus theme styles muted by default.
(use-package paren-face
  :hook ((emacs-lisp-mode lisp-mode lisp-data-mode
          scheme-mode clojure-mode lisp-interaction-mode)
         . paren-face-mode))

;; λ for lambda. Built-in, no package needed. `unprettify-at-point' makes
;; the literal `lambda' reappear when the cursor is on it, so editing
;; semantics are unchanged — only the displayed glyph shifts.
;; Codepoints (not `?λ' literals) sidestep emacsWithPackagesFromUsePackage's
;; regex parser, which doesn't tokenize multi-byte char literals.
(defun my/lispy-prettify ()
  (setq prettify-symbols-alist
        '(("lambda"  . 955)    ; λ
          ("defun"   . 402)    ; ƒ
          (">="      . 8805)   ; ≥
          ("<="      . 8804)   ; ≤
          ("not"     . 172)))  ; ¬
  (prettify-symbols-mode 1))

(setq prettify-symbols-unprettify-at-point 'right-edge)

(dolist (h '(emacs-lisp-mode-hook lisp-mode-hook
             lisp-interaction-mode-hook scheme-mode-hook))
  (add-hook h #'my/lispy-prettify))

;; Subtle vertical indent bars — depth-of-form at a glance.
(use-package indent-bars
  :hook (prog-mode . indent-bars-mode)
  :custom
  (indent-bars-color '(highlight :face-bg t :blend 0.2))
  (indent-bars-pattern ".")
  (indent-bars-width-frac 0.15)
  (indent-bars-pad-frac 0.4)
  (indent-bars-zigzag nil)
  (indent-bars-display-on-blank-lines nil))

;; Soft glow on the parens enclosing point — your current scope, faintly
;; visible at every nesting depth.
(use-package highlight-parentheses
  :hook ((emacs-lisp-mode lisp-mode lisp-data-mode
          scheme-mode clojure-mode lisp-interaction-mode)
         . highlight-parentheses-mode)
  :custom
  (highlight-parentheses-colors '("#7aa2f7" "#9d7cd8" "#7dcfff" "#bb9af7"))
  (highlight-parentheses-attributes '((:weight bold))))

;;; ui.el ends here
