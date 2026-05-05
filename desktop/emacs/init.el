;;; init.el --- entry point -*- lexical-binding: t; no-byte-compile: t; -*-

;; Packages are installed by Nix via emacsWithPackagesFromUsePackage, which
;; parses every `(use-package ...)' across this file *and* the modules under
;; `lisp/' at flake-eval time (see desktop/emacs/default.nix — modules are
;; concatenated into a single derivation just for the parser; on disk they
;; stay separate). Built-in packages use :ensure nil so the parser skips
;; them.

(eval-when-compile (require 'use-package))

(setq use-package-always-defer t
      use-package-always-ensure nil
      use-package-expand-minimally t)

;;; Profiling infrastructure --------------------------------------------------

;; Native-compile every elisp file we load (and on save). Catches packages
;; whose maintainers didn't ship .eln/.elc.
(use-package compile-angel
  :demand t
  :custom (compile-angel-verbose nil)
  :config
  (compile-angel-on-load-mode)
  (add-hook 'emacs-lisp-mode-hook #'compile-angel-on-save-local-mode))

;; Startup profiler — only loaded under EMACS_BENCH=1.
;; Run: `EMACS_BENCH=1 emacs` then M-x benchmark-init/show-durations-tree.
(when (getenv "EMACS_BENCH")
  (use-package benchmark-init
    :demand t
    :config (add-hook 'after-init-hook #'benchmark-init/deactivate)))

;;; Helpers --------------------------------------------------------------------
;; Top-level so they show up in imenu and grep, instead of being buried inside
;; `use-package' :config blocks. Referenced by name from modules below; nothing
;; here is invoked at load time. Helpers stay in init.el (rather than a module)
;; so module load order doesn't matter — every module sees them already defined.

(defun my/popup-frame-params (kind)
  "Frame params for a popup of KIND. The name drives niri's window-rule match."
  `((name . ,(format "popup:%s" kind))
    (width . 100) (height . 32)
    (unsplittable . t)))

(defun my/popup-rule (regex kind)
  "`display-buffer-alist' rule that pops a niri-managed frame for REGEX.
Frame is named `popup:KIND' so niri's window-rule can match on it."
  `(,regex
    (display-buffer-reuse-window display-buffer-pop-up-frame)
    (reusable-frames . t)
    (pop-up-frame-parameters . ,(my/popup-frame-params kind))))

(defun my/eglot-web-mode-server (_interactive)
  "Pick a language server for the current `web-mode' buffer.
Currently only Vue single-file components get one."
  (cond
   ((and buffer-file-name (string-match-p "\\.vue\\'" buffer-file-name))
    '("vue-language-server" "--stdio"))))

(defun my/maybe-vue-eglot ()
  "Start eglot in `web-mode' buffers visiting Vue single-file components."
  (when (and buffer-file-name
             (string-match-p "\\.vue\\'" buffer-file-name))
    (eglot-ensure)))

(defvar my/envrc--prompted-dirs nil
  "Directories already prompted about a blocked .envrc this session.")

(defun my/envrc-maybe-prompt-allow ()
  "Offer `direnv allow' when the buffer's .envrc is blocked.
Fires from `envrc-mode-hook' for file-visiting buffers where envrc
flagged an error; spawns `direnv status' to confirm the cause is
specifically a blocked rc (not a syntax error or failing build).
Each dir is prompted at most once per session."
  (when (and (bound-and-true-p envrc-mode)
             buffer-file-name
             (eq envrc--status 'error)
             (executable-find "direnv"))
    (when-let* ((dir (locate-dominating-file default-directory ".envrc")))
      (unless (member dir my/envrc--prompted-dirs)
        (push dir my/envrc--prompted-dirs)
        (let ((blocked
               (with-temp-buffer
                 (let ((default-directory dir))
                   (call-process "direnv" nil t nil "status"))
                 (goto-char (point-min))
                 (re-search-forward "Found RC allowed false" nil t))))
          (when (and blocked
                     (y-or-n-p
                      (format ".envrc in %s is blocked. Run `direnv allow'? "
                              (abbreviate-file-name dir))))
            (envrc-allow)))))))

(defun my/project-switch-in-new-frame ()
  "Pick a project and open it in a new frame named after the project."
  (interactive)
  (let* ((dir (project-prompt-project-dir))
         (name (file-name-nondirectory (directory-file-name dir))))
    (select-frame (make-frame `((name . ,name))))
    (let ((default-directory dir))
      (project-switch-project dir))))

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

(defun my/announce-init-time ()
  "Log emacs init time to *Messages*."
  (message "Emacs init in %s with %d GCs"
           (emacs-init-time) gcs-done))

;;; Hand off post-startup GC to gcmh ------------------------------------------
;; Lives up here (rather than after UI polish) so later `use-package' loads
;; run with the lower idle GC threshold once gcmh has settled in.

(use-package gcmh
  :demand t
  :config
  (setq gcmh-idle-delay 'auto
        gcmh-auto-idle-delay-factor 10
        gcmh-high-cons-threshold (* 128 1024 1024))
  (gcmh-mode 1))

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
 redisplay-skip-fontification-on-input t
 redisplay-skip-cursor-motion t
 fast-but-imprecise-scrolling t
 jit-lock-defer-time 0.05
 jit-lock-stealth-time 1
 idle-update-delay 1.0
 auto-window-vscroll nil
 window-resize-pixelwise t
 highlight-nonselected-windows nil
 bidi-inhibit-bpa t)

(setq-default indent-tabs-mode nil
              tab-width 2
              cursor-in-non-selected-windows nil
              bidi-display-reordering 'left-to-right
              bidi-paragraph-direction 'left-to-right)

;; Absolute numbers redraw the gutter only when crossing a line; relative
;; redraws every cursor motion. Opt-in to prog/text rather than global so
;; magit/help/dired/vterm don't pay the cost.
(setq display-line-numbers-type t
      display-line-numbers-width-start t
      display-line-numbers-grow-only t)
(dolist (h '(prog-mode-hook text-mode-hook conf-mode-hook))
  (add-hook h #'display-line-numbers-mode))

;; Vertical line at fill-column — code-as-architecture.
(add-hook 'prog-mode-hook #'display-fill-column-indicator-mode)

;; Solid block cursor, non-blinking.
(setq-default cursor-type 'box)
(blink-cursor-mode -1)

(global-auto-revert-mode 1)
(savehist-mode 1)
(save-place-mode 1)
(recentf-mode 1)
(delete-selection-mode 1)
(electric-pair-mode 1)
(repeat-mode 1)
(global-so-long-mode 1)
(pixel-scroll-precision-mode 1)

;; Demote the expensive minor modes when a buffer is big enough that they
;; show up in profiles. Complements `global-so-long-mode' (which catches
;; minified single-line files).
(defun my/buffer-is-heavy-p ()
  (or (> (buffer-size) (* 256 1024))
      (and buffer-file-name
           (> (or (file-attribute-size (file-attributes buffer-file-name)) 0)
              (* 256 1024)))))

(defun my/tame-heavy-buffer ()
  (when (my/buffer-is-heavy-p)
    (when (bound-and-true-p display-line-numbers-mode) (display-line-numbers-mode -1))
    (when (bound-and-true-p diff-hl-mode)              (diff-hl-mode -1))
    (when (bound-and-true-p flymake-mode)              (flymake-mode -1))
    (when (fboundp 'eldoc-mode)                        (eldoc-mode -1))
    (setq-local bidi-paragraph-direction 'left-to-right
                bidi-inhibit-bpa t)))

(add-hook 'find-file-hook #'my/tame-heavy-buffer)
(add-hook 'after-change-major-mode-hook #'my/tame-heavy-buffer)
;; Touchpad keeps pixel-precision (smooth glide); discrete mouse-wheel events
;; skip interpolation and fall through to plain `mouse-wheel-scroll-amount'.
(setq pixel-scroll-precision-interpolate-mice nil)

;; Mouse wheel: one notch = one line, no progressive acceleration on fast spins.
;; (`mouse-wheel-follow-mouse' is already t by default.)
(setq mouse-wheel-scroll-amount '(1 ((shift) . hscroll) ((control) . text-scale))
      mouse-wheel-progressive-speed nil)

;;; Modules --------------------------------------------------------------------
;; Each module is a plain `.el' under `lisp/', loaded by absolute path so it
;; never collides with any feature of the same name on `load-path'. Order is
;; deliberate: editor before completion (evil binds before vertico), code
;; before project (eglot before envrc hook), keys last (binds reach commands
;; from every other module).

(dolist (mod '("ui" "editor" "completion" "code" "project" "tools" "mail" "keys"))
  (load (expand-file-name (concat "lisp/" mod) user-emacs-directory)
        nil 'nomessage))

;;; Startup banner -------------------------------------------------------------

(add-hook 'emacs-startup-hook #'my/announce-init-time)

;;; init.el ends here
