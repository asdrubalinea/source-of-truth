;;; project.el --- project, frames, popups, magit -*- lexical-binding: t; no-byte-compile: t; -*-

;;; Project & workspace -------------------------------------------------------

(use-package envrc
  :hook ((after-init  . envrc-global-mode)
         (envrc-mode  . my/envrc-maybe-prompt-allow)))

(use-package beframe
  :demand t
  :custom
  (beframe-functions-in-frames '(clone-frame))
  (beframe-global-buffers
   '("*scratch*" "*Messages*" "*Backtrace*" "*claude:*"
     "*Help*" "*helpful" "*compilation*" "*Async Shell Command"
     "magit" "*vterm" "*eshell" "*shell"))
  :config
  (beframe-mode 1)
  ;; Make consult-buffer respect beframe's per-frame scope.
  (with-eval-after-load 'consult
    (defvar beframe-consult-source
      `(:name "Frame buffers"
              :narrow ?F
              :category buffer
              :face beframe-face
              :history beframe-history
              :items ,#'beframe-buffer-names
              :action ,#'switch-to-buffer
              :state ,#'consult--buffer-state))
    (add-to-list 'consult-buffer-sources 'beframe-consult-source)))

;;; Hand persistent popup buffers off to the WM as their own frame ------------
;; Transient popups (which-key, corfu, eldoc) use child frames and stay inside
;; Emacs. Frames named `popup:*' are matched by a niri window-rule and float
;; at a sane default size. See `my/popup-rule' / `my/popup-frame-params' in
;; init.el's Helpers section.

(setq display-buffer-alist
      (mapcar (pcase-lambda (`(,re ,kind)) (my/popup-rule re kind))
              '(("\\`\\*magit[^*]*\\*"                              "magit")
                ("\\`\\*\\(compilation\\|Async Shell Command\\)\\*" "compile")
                ("\\`\\*\\(Help\\|helpful .*\\)\\*"                 "help")
                ("\\`\\*\\(vterm\\|eat\\|eshell\\|shell\\).*\\*"    "term")
                ("\\`\\*claude:"                                    "claude"))))

(use-package dired-sidebar
  :commands (dired-sidebar-toggle-sidebar dired-sidebar-show-sidebar)
  :custom
  (dired-sidebar-theme 'nerd-icons)
  (dired-sidebar-use-term-integration t)
  (dired-sidebar-use-custom-modeline nil)
  (dired-sidebar-should-follow-file t)
  (dired-sidebar-width 32))

(use-package project
  :ensure nil
  :custom
  (project-vc-extra-root-markers '(".project" ".git"))
  (project-switch-commands #'project-dired))

;;; Magit ----------------------------------------------------------------------

(use-package magit
  :defer t
  :bind (("C-x g" . magit-status))
  :custom
  (magit-diff-refine-hunk t)
  (magit-save-repository-buffers 'dontask)
  (magit-process-finish-apply-ansi-colors t))

(use-package forge
  :after magit)

;;; project.el ends here
