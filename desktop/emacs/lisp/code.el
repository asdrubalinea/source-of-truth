;;; code.el --- tree-sitter, LSP, language modes -*- lexical-binding: t; no-byte-compile: t; -*-

;;; Tree-sitter ----------------------------------------------------------------

(use-package treesit
  :ensure nil
  :demand t
  :config
  (setq treesit-font-lock-level 4)
  ;; php-ts-mode (built-in) is omitted: its bundled font-lock query references
  ;; node types that don't exist in the current tree-sitter-php grammar
  ;; nixpkgs ships, so it errors on fontify. The third-party `php-mode'
  ;; below handles .php instead.
  (dolist (m '((python-mode . python-ts-mode)
               (c-mode . c-ts-mode)
               (c++-mode . c++-ts-mode)
               (rust-mode . rust-ts-mode)
               (js-mode . js-ts-mode)
               (typescript-mode . typescript-ts-mode)
               (go-mode . go-ts-mode)
               (yaml-mode . yaml-ts-mode)
               (json-mode . json-ts-mode)
               (bash-mode . bash-ts-mode)))
    (add-to-list 'major-mode-remap-alist m))
  ;; Built-in ts-modes don't auto-register file extensions; wire them up so
  ;; opening a .ts/.tsx file actually lands in the tree-sitter mode.
  (dolist (entry '(("\\.tsx\\'" . tsx-ts-mode)
                   ("\\.ts\\'"  . typescript-ts-mode)
                   ("\\.mjs\\'" . js-ts-mode)
                   ("\\.cjs\\'" . js-ts-mode)))
    (add-to-list 'auto-mode-alist entry)))

;;; LSP / diagnostics / docs ---------------------------------------------------

(use-package lsp-mode
  :commands (lsp lsp-deferred)
  :hook ((python-ts-mode rust-ts-mode go-ts-mode
          c-ts-mode c++-ts-mode
          js-ts-mode typescript-ts-mode tsx-ts-mode
          nix-mode typst-ts-mode php-mode) . lsp-deferred)
  :init
  (setq lsp-keymap-prefix "C-c l"
        lsp-idle-delay 0.5
        lsp-log-io nil
        ;; corfu owns completion — don't let lsp-mode pull in company.
        lsp-completion-provider :none
        ;; breadcrumb-mode already covers this; avoid duplicate UI.
        lsp-headerline-breadcrumb-enable nil
        lsp-modeline-diagnostics-enable t
        lsp-modeline-code-actions-enable t
        lsp-nix-nil-server-path "nil")
  :custom
  (lsp-eldoc-render-all nil)
  :config
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection "tinymist")
    :major-modes '(typst-ts-mode)
    :server-id 'tinymist))
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection '("phpactor" "language-server"))
    :major-modes '(php-mode)
    :server-id 'phpactor)))

(use-package lsp-ui
  :hook (lsp-mode . lsp-ui-mode)
  :custom
  (lsp-ui-doc-enable t)
  (lsp-ui-doc-position 'at-point)
  (lsp-ui-doc-show-with-cursor nil)
  (lsp-ui-doc-show-with-mouse nil)
  (lsp-ui-sideline-show-diagnostics t)
  (lsp-ui-sideline-show-hover nil)
  (lsp-ui-sideline-show-code-actions t)
  (lsp-ui-peek-enable t))

(use-package consult-lsp
  :after (consult lsp-mode))

(use-package flycheck
  :init (global-flycheck-mode)
  :custom
  (flycheck-check-syntax-automatically '(save idle-change mode-enabled))
  (flycheck-idle-change-delay 0.5))

(use-package consult-flycheck
  :after (consult flycheck))

(use-package eldoc
  :ensure nil
  :custom
  (eldoc-echo-area-use-multiline-p nil)
  (eldoc-idle-delay 0.2))

(use-package apheleia
  :demand t
  :config (apheleia-global-mode 1))

;;; Help & docs ---------------------------------------------------------------

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

(use-package php-mode
  :mode "\\.php\\'")

(use-package typst-ts-mode
  :mode ("\\.typ\\'" . typst-ts-mode))

(use-package web-mode
  :mode (("\\.html?\\'"      . web-mode)
         ("\\.blade\\.php\\'" . web-mode)
         ("\\.vue\\'"         . web-mode))
  :hook (web-mode . my/maybe-vue-lsp)
  :custom
  (web-mode-markup-indent-offset 2)
  (web-mode-css-indent-offset 2)
  (web-mode-code-indent-offset 2)
  (web-mode-enable-auto-pairing t)
  (web-mode-enable-auto-quoting nil)
  (web-mode-enable-current-element-highlight t))

;;; code.el ends here
