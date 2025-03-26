;; Basic performance settings
(setq gc-cons-threshold 100000000)
(setq read-process-output-max (* 1024 1024))

;; UI improvements
(tool-bar-mode -1)
(scroll-bar-mode -1)
(setq visible-bell t)

;; Editing essentials
(electric-pair-mode t)
(show-paren-mode 1)
(setq-default indent-tabs-mode nil)

;; Display line numbers
(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode)
;; Disable line numbers for some modes
(dolist (mode '(term-mode-hook
                shell-mode-hook
                eshell-mode-hook))
  (add-hook mode (lambda () (display-line-numbers-mode 0))))

;; Startup settings
(setq-default
 inhibit-startup-screen t               ; Disable start-up screen
 inhibit-startup-message t              ; Disable startup message
 inhibit-startup-echo-area-message t    ; Disable initial echo message
 initial-scratch-message ""             ; Empty the initial _scratch_ buffer
 initial-buffer-choice t)               ; Open _scratch_ buffer at init

;; Session persistence
(save-place-mode t)
(savehist-mode t)
(recentf-mode t)

;; Auto revert files when changed on disk
(global-auto-revert-mode t)

;; Auto-save settings
(let ((my-auto-save-dir (locate-user-emacs-file "auto-save")))
  (setq auto-save-file-name-transforms
        `((".*" ,(expand-file-name "\\2" my-auto-save-dir) t)))
  (unless (file-exists-p my-auto-save-dir)
    (make-directory my-auto-save-dir)))
(setq auto-save-default t
      auto-save-timeout 10
      auto-save-interval 200)

;; Font settings
(add-to-list 'default-frame-alist
             '(font . "Maple Mono 24"))

;; Keybindings
;; invoke M-x without Alt
(global-set-key (kbd "C-x C-m") 'execute-extended-command)
;; Make ESC quit prompts
(global-set-key (kbd "<escape>") 'keyboard-escape-quit)

;; Fast reload config
(defun reload-init-file ()
  (interactive)
  (load-file user-init-file))
(global-set-key (kbd "<f5>") 'reload-init-file)

