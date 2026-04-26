;;; early-init.el --- pre-frame setup -*- lexical-binding: t; no-byte-compile: t; -*-

(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

(defvar my/file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist my/file-name-handler-alist)))

;; package-enable-at-startup is intentionally left at its default (t).
;; Nix bundles every elpa subdir with its *-autoloads.el; package-activate-all
;; runs them so use-package :init (foo-mode) sees the autoloaded function.

(setq default-frame-alist
      '((menu-bar-lines . 0)
        (tool-bar-lines . 0)
        (vertical-scroll-bars)
        (horizontal-scroll-bars)
        (internal-border-width . 8)))

(setq inhibit-startup-screen t
      inhibit-startup-message t
      inhibit-startup-buffer-menu t
      initial-scratch-message nil)

(setq frame-inhibit-implied-resize t
      frame-resize-pixelwise t)

(setq native-comp-async-report-warnings-errors 'silent
      native-comp-jit-compilation t)

(set-language-environment "UTF-8")
(setq default-input-method nil)

;;; early-init.el ends here
