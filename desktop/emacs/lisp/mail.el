;;; mail.el --- mu4e contexts, org-msg, alerts -*- lexical-binding: t; no-byte-compile: t; -*-

;; mu4e is loaded via the `mu' package (Nix-side `trivialBuild' shim in
;; desktop/emacs/default.nix), so `:ensure nil' here keeps the use-package
;; parser from trying to fetch it.
(use-package mu4e
  :ensure nil
  :commands (mu4e mu4e-compose-new)
  :custom
  (mu4e-maildir "~/Mail")
  (mu4e-update-interval 300)
  (mu4e-get-mail-command "mbsync -a")
  (mu4e-change-filenames-when-moving t)
  (mu4e-attachment-dir "~/Downloads")
  (mu4e-confirm-quit nil)
  (mu4e-use-fancy-chars t)
  (mu4e-headers-skip-duplicates t)
  (message-send-mail-function #'message-send-mail-with-sendmail)
  (sendmail-program "msmtp")
  (mail-specify-envelope-from t)
  (message-sendmail-envelope-from 'header)
  (mail-envelope-from 'header)
  :config
  (setq mu4e-contexts
        (list
         (make-mu4e-context
          :name "fastmail"
          :match-func
          (lambda (msg)
            (when msg
              (string-prefix-p "/fastmail"
                               (mu4e-message-field msg :maildir))))
          :vars '((user-mail-address  . "hi@irene.foo")
                  (user-full-name     . "Irene Lena")
                  (mu4e-sent-folder   . "/fastmail/Sent")
                  (mu4e-drafts-folder . "/fastmail/Drafts")
                  (mu4e-trash-folder  . "/fastmail/Trash")
                  (mu4e-refile-folder . "/fastmail/Archive")))
         (make-mu4e-context
          :name "pec"
          :match-func
          (lambda (msg)
            (when msg
              (string-prefix-p "/pec"
                               (mu4e-message-field msg :maildir))))
          :vars '((user-mail-address  . "asdrubalini@pec.it")
                  (user-full-name     . "Irene Lena")
                  (mu4e-sent-folder   . "/pec/Sent")
                  (mu4e-drafts-folder . "/pec/Drafts")
                  (mu4e-trash-folder  . "/pec/Trash")
                  (mu4e-refile-folder . "/pec/Archive"))))))

(use-package org-msg
  :after mu4e
  :hook (mu4e-compose-pre . org-msg-mode)
  :custom
  (org-msg-default-alternatives '((new           . (text html))
                                  (reply-to-html . (text html))
                                  (reply-to-text . (text))))
  (org-msg-startup "hidestars indent inlineimages"))

(use-package mu4e-alert
  :after mu4e
  :custom
  ;; Only inboxes — silence noise from list-archives etc.
  (mu4e-alert-interesting-mail-query
   (concat "flag:unread AND NOT flag:trashed AND "
           "(maildir:/fastmail/INBOX OR maildir:/pec/INBOX)"))
  :config
  ;; Built-in DBus client → Mako picks the notification up on niri.
  (mu4e-alert-set-default-style 'notifications)
  (mu4e-alert-enable-notifications)
  (mu4e-alert-enable-mode-line-display))

;;; mail.el ends here
