;;; Elpaca Bootstrap
(defvar elpaca-installer-version 0.7)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-repos-directory (expand-file-name "repos/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca--activate-package)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-repos-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (< emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                 ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                 ,@(when-let ((depth (plist-get order :depth)))
                                                     (list (format "--depth=%d" depth) "--no-single-branch"))
                                                 ,(plist-get order :repo) ,repo))))
                 ((zerop (call-process "git" nil buffer t "checkout"
                                       (or (plist-get order :ref) "--"))))
                 (emacs (concat invocation-directory invocation-name))
                 ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                       "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                 ((require 'elpaca))
                 ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (load "./elpaca-autoloads")))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

;; Install use-package support
(elpaca elpaca-use-package
  ;; Enable use-package :elpaca support.
  (elpaca-use-package-mode))

;;; Wait for Elpaca to be ready before continuing
(elpaca-wait)

;;; Basic performance settings
(setq gc-cons-threshold 100000000)
(setq read-process-output-max (* 1024 1024))

;;; UI improvements
(tool-bar-mode -1)
(scroll-bar-mode -1)
(setq visible-bell t)

;;; Editing essentials
(electric-pair-mode t)
(show-paren-mode 1)
(setq-default indent-tabs-mode nil)

;;; Display line numbers
(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode)
;; Disable line numbers for some modes
(dolist (mode '(term-mode-hook
                shell-mode-hook
                eshell-mode-hook))
  (add-hook mode (lambda () (display-line-numbers-mode 0))))

;;; Startup settings
(setq-default
 inhibit-startup-screen t               ; Disable start-up screen
 inhibit-startup-message t              ; Disable startup message
 inhibit-startup-echo-area-message t    ; Disable initial echo message
 initial-scratch-message ""             ; Empty the initial _scratch_ buffer
 initial-buffer-choice t)               ; Open _scratch_ buffer at init

;;; Session persistence
(save-place-mode t)
(savehist-mode t)
(recentf-mode t)

;;; Auto revert files when changed on disk
(global-auto-revert-mode t)

;;; Auto-save settings
(let ((my-auto-save-dir (locate-user-emacs-file "auto-save")))
  (setq auto-save-file-name-transforms
        `((".*" ,(expand-file-name "\\2" my-auto-save-dir) t)))
  (unless (file-exists-p my-auto-save-dir)
    (make-directory my-auto-save-dir)))
(setq auto-save-default t
      auto-save-timeout 10
      auto-save-interval 200)

;;; Font settings
(add-to-list 'default-frame-alist
             '(font . "Maple Mono 24"))

;;; Evil Mode Configuration
(use-package evil
  :elpaca t
  :init
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  (setq evil-want-C-u-scroll t)
  (setq evil-want-C-i-jump nil)
  (setq evil-respect-visual-line-mode t)
  (setq evil-undo-system 'undo-redo)
  :config
  (evil-mode 1)
  ;; Use visual line motions even outside of visual-line-mode buffers
  (evil-global-set-key 'motion "j" 'evil-next-visual-line)
  (evil-global-set-key 'motion "k" 'evil-previous-visual-line)
  
  ;; Set initial state for some modes
  (evil-set-initial-state 'messages-buffer-mode 'normal)
  (evil-set-initial-state 'dashboard-mode 'normal))

(use-package evil-collection
  :elpaca t
  :after evil
  :config
  (evil-collection-init))

(use-package evil-commentary
  :elpaca t
  :after evil
  :config
  (evil-commentary-mode))

;;; General keybinding framework
(use-package general
  :elpaca t
  :after evil
  :config
  (general-create-definer my/leader-keys
    :keymaps '(normal insert visual emacs)
    :prefix "SPC"
    :global-prefix "C-SPC")
  
  (my/leader-keys
    "f" '(:ignore t :which-key "file")
    "ff" '(find-file :which-key "find file")
    "fs" '(save-buffer :which-key "save file")
    "fr" '(recentf-open-files :which-key "recent files")
    
    "b" '(:ignore t :which-key "buffer")
    "bb" '(switch-to-buffer :which-key "switch buffer")
    "bk" '(kill-buffer :which-key "kill buffer")
    "bn" '(next-buffer :which-key "next buffer")
    "bp" '(previous-buffer :which-key "previous buffer")
    
    "w" '(:ignore t :which-key "window")
    "wh" '(evil-window-left :which-key "window left")
    "wj" '(evil-window-down :which-key "window down")
    "wk" '(evil-window-up :which-key "window up")
    "wl" '(evil-window-right :which-key "window right")
    "ws" '(evil-window-split :which-key "split horizontal")
    "wv" '(evil-window-vsplit :which-key "split vertical")
    "wd" '(evil-window-delete :which-key "delete window")
    
    "q" '(:ignore t :which-key "quit")
    "qq" '(evil-quit :which-key "quit")
    "qQ" '(evil-quit-all :which-key "quit all")))

;;; Which-key for keybinding discovery
(use-package which-key
  :elpaca t
  :init (which-key-mode)
  :diminish which-key-mode
  :config
  (setq which-key-idle-delay 0.3))

;;; Keybindings
;; invoke M-x without Alt
(global-set-key (kbd "C-x C-m") 'execute-extended-command)
;; Make ESC quit prompts
(global-set-key (kbd "<escape>") 'keyboard-escape-quit)

;;; Fast reload config
(defun reload-init-file ()
  (interactive)
  (load-file user-init-file))
(global-set-key (kbd "<f5>") 'reload-init-file)

