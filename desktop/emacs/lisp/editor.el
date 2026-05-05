;;; editor.el --- modal editing, state hygiene, clipboard -*- lexical-binding: t; no-byte-compile: t; -*-

;;; Keep state out of ~/.config/emacs ------------------------------------------

(use-package no-littering
  :demand t
  :config
  (no-littering-theme-backups)
  (setq custom-file (no-littering-expand-etc-file-name "custom.el"))
  (when (file-exists-p custom-file) (load custom-file 'noerror)))

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

;;; editor.el ends here
