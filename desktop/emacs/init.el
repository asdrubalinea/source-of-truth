;;; init.el --- -*- lexical-binding: t; -*-

;; Packages are installed by Nix via emacsWithPackagesFromUsePackage,
;; which parses the (use-package ...) declarations below at flake-eval
;; time.

(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024)
                  gc-cons-percentage 0.1)))

(setq inhibit-startup-screen t
      inhibit-startup-message t
      initial-scratch-message ""
      ring-bell-function 'ignore
      use-short-answers t
      create-lockfiles nil
      make-backup-files nil)

(when (fboundp 'tool-bar-mode)   (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(when (fboundp 'menu-bar-mode)   (menu-bar-mode -1))

(setq-default indent-tabs-mode nil
              tab-width 2)

(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode 1)

(add-to-list 'default-frame-alist '(font . "Maple Mono 13"))

(require 'use-package)

(use-package evil
  :demand t
  :init
  (setq evil-want-C-u-scroll t
        evil-undo-system 'undo-redo)
  :config
  (evil-mode 1))

;;; init.el ends here
