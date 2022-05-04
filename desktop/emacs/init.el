;; Emacs Straight
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 5))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; Disable package.el in favor of straight.el
(setq package-enable-at-startup nil)

(straight-use-package 'use-package)

(use-package emacs
  :config
  (setq user-full-name "Asdrubalini")
  (setq ring-bell-function 'ignore)
  (setq-default default-directory "/persist/")
  (setq frame-resize-pixelwise t)
  (setq scroll-conservatively 101) ; > 100
  (setq scroll-preserve-screen-position t)
  (setq auto-window-vscroll nil)
  (setq load-prefer-newer t)
  (setq inhibit-compacting-font-caches t)
  (setq echo-keystrokes 0.02)
  (tool-bar-mode -1)
  (menu-bar-mode -1)
  (setq-default line-spacing 3)
  (setq-default indent-tabs-mode nil)
  ;; Set default font face
  (set-face-attribute 'default nil :font "Operator Mono Medium" :height 175)
  (setq org-support-shift-select t)
  ;; Enable line numbering by default
  (global-display-line-numbers-mode t)
  (setq inhibit-startup-screen t))

;; Inhibit scratch message
(use-package "startup"
  :ensure nil
  :config
  (setq initial-scratch-message ""))

;; Inhibit scroll bar
(use-package scroll-bar
  :ensure nil
  :config
  (scroll-bar-mode -1))

(use-package files
  :ensure nil
  :config
  (setq confirm-kill-processes nil)
  (setq create-lockfiles nil) ; don't create .# files (crashes 'npm start')
  (setq backup-directory-alist `(("." . "~/.emacs.bak"))))

;; Evil mode
(use-package evil
  :straight t
  :ensure t
  :config
  (evil-mode 1))

(use-package nix-mode
  :straight t
  :ensure t
  :mode "\\.nix\\'")

;; Themes
(use-package doom-themes
  :straight t
  :ensure t
  :config
  ;; (load-theme 'doom-challenger-deep t)
  (load-theme 'doom-one t)

  ;; Enable flashing mode-line on errors
  (doom-themes-visual-bell-config)
  ;; Enable custom neotree theme (all-the-icons must be installed!)
  (doom-themes-neotree-config)
  ;; or for treemacs users
  (setq doom-themes-treemacs-theme "doom-colors")
  (doom-themes-treemacs-config)
  ;; Corrects (and improves) org-mode's native fontification.
  (doom-themes-org-config))

(use-package tree-sitter
  :straight t
  :ensure t)

(use-package tree-sitter-langs
  :straight t
  :ensure t)

(use-package rust-mode
  :straight t
  :ensure t)

;; Org mode
(use-package org-contrib
  :straight t
  :ensure t)

;; This is required to highlight code blocks properly
(use-package htmlize
  :straight t
  :ensure t)

(use-package ivy
  :straight t
  :ensure t
  :config
    (ivy-mode)
    (setq ivy-use-virtual-buffers t)
    (setq enable-recursive-minibuffers t)
  )

;; Magit
(use-package magit
  :straight t
  :ensure t)

(use-package paren
  :straight t
  :ensure t
  :init (setq show-paren-delay 0)
  :config (show-paren-mode +1))

(use-package elec-pair
  :straight t
  :ensure t
  :hook (prog-mode . electric-pair-mode))

(use-package whitespace
  :straight t
  :ensure t
  :hook (before-save . whitespace-cleanup))

(use-package dired
  :ensure nil
  :hook ((dired-mode . dired-hide-details-mode)
         (dired-mode . hl-line-mode))
  :config
  (put 'dired-find-alternate-file 'disabled nil))

(use-package helm
  :straight t
  :ensure t
  :init
  (helm-mode 1))
