;;; tools.el --- AI assistant, terminals, org, prose -*- lexical-binding: t; no-byte-compile: t; -*-

;;; AI assistant --------------------------------------------------------------

(use-package claude-code-ide
  :defer t
  :commands (claude-code-ide claude-code-ide-menu
                             claude-code-ide-switch-to-buffer
                             claude-code-ide-send-prompt
                             claude-code-ide-continue
                             claude-code-ide-resume
                             claude-code-ide-stop
                             claude-code-ide-list-sessions)
  :custom
  (claude-code-ide-terminal-backend 'eat)
  (claude-code-ide-no-flicker t))

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

;;; PDF viewing ----------------------------------------------------------------

;; epdfinfo (the poppler helper) is built by nixpkgs `emacsPackages.pdf-tools`,
;; so no `pdf-tools-install` prompt at runtime — the binary is already on disk.
(use-package pdf-tools
  :magic ("%PDF" . pdf-view-mode)
  :hook (pdf-view-mode . (lambda () (display-line-numbers-mode -1)))
  :custom
  (pdf-view-display-size 'fit-page)
  (pdf-view-use-scaling t)
  (pdf-annot-activate-created-annotations t)
  :config
  (pdf-tools-install :no-query))

(use-package saveplace-pdf-view
  :after pdf-tools
  :config
  (save-place-mode 1))

;;; Centered prose --------------------------------------------------------------

(use-package olivetti
  :hook ((text-mode . olivetti-mode)
         (org-mode  . olivetti-mode))
  :custom
  (olivetti-body-width 100)
  (olivetti-minimum-body-width 80)
  (olivetti-style 'fancy))

;;; tools.el ends here
