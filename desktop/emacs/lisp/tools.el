;;; tools.el --- AI assistant, terminals, org, prose -*- lexical-binding: t; no-byte-compile: t; -*-

;;; AI assistant --------------------------------------------------------------

(use-package claude-code
  :defer t
  :commands (claude-code claude-code-transient claude-code-send-region
                         claude-code-switch-to-buffer claude-code-kill
                         claude-code-send-buffer-file claude-code-cycle-mode)
  :custom
  (claude-code-terminal-backend 'ghostel))

;;; Terminal -------------------------------------------------------------------

(use-package vterm
  :defer t
  :commands vterm
  :custom
  (vterm-max-scrollback 100000)
  (vterm-timer-delay 0.01))

(use-package eat
  :defer t
  :commands (eat eat-project eat-other-window)
  :custom
  (eat-kill-buffer-on-exit t)
  (eat-enable-mouse t)
  :hook ((eshell-load-hook . eat-eshell-mode)
         (eshell-load-hook . eat-eshell-visual-command-mode)))

(use-package ghostel
  :defer t
  :commands (ghostel ghostel-project)
  :custom
  ;; Module .so ships in the nix-built elpa dir — never download or compile
  ;; at runtime.
  (ghostel-module-auto-install nil))

;;; Org ------------------------------------------------------------------------

(use-package org
  :defer t
  :hook ((org-mode . org-indent-mode)
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

;;; Centered prose --------------------------------------------------------------

(use-package olivetti
  :hook ((text-mode . olivetti-mode)
         (org-mode  . olivetti-mode))
  :custom
  (olivetti-body-width 100)
  (olivetti-minimum-body-width 80)
  (olivetti-style 'fancy))

;;; tools.el ends here
