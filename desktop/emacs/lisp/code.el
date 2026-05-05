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

(use-package eglot
  :ensure nil
  :hook ((python-ts-mode rust-ts-mode go-ts-mode
                         c-ts-mode c++-ts-mode
                         js-ts-mode typescript-ts-mode tsx-ts-mode
                         nix-mode typst-ts-mode
                         php-mode) . eglot-ensure)
  :custom
  (eglot-autoshutdown t)
  (eglot-events-buffer-size 0)
  (eglot-events-buffer-config '(:size 0 :format short))
  (eglot-sync-connect 0)
  (eglot-extend-to-xref t)
  (eglot-send-changes-idle-time 0.2)
  (eglot-report-progress nil)
  :config
  (fset #'jsonrpc--log-event #'ignore)
  (add-to-list 'eglot-server-programs '(nix-mode . ("nil")))
  (add-to-list 'eglot-server-programs '(typst-ts-mode . ("tinymist")))
  (add-to-list 'eglot-server-programs
               '(php-mode . ("phpactor" "language-server")))
  (add-to-list 'eglot-server-programs
               '(web-mode . my/eglot-web-mode-server)))

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
  :hook (web-mode . my/maybe-vue-eglot)
  :custom
  (web-mode-markup-indent-offset 2)
  (web-mode-css-indent-offset 2)
  (web-mode-code-indent-offset 2)
  (web-mode-enable-auto-pairing t)
  (web-mode-enable-auto-quoting nil)
  (web-mode-enable-current-element-highlight t))

;;; code.el ends here
