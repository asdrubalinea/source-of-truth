;;; keys.el --- general.el leader bindings -*- lexical-binding: t; no-byte-compile: t; -*-

(use-package general
  :demand t
  :after evil
  :config
  (general-evil-setup)
  (general-create-definer my/leader
    :states '(normal visual motion emacs)
    :keymaps 'override
    :prefix "SPC"
    :prefix-map 'my/leader-map
    :non-normal-prefix "M-SPC")

  (my/leader
    "SPC" '(project-find-file       :wk "find file in project")
    "?"   '(my/show-leader-bindings :wk "show leader bindings")
    "."   '(find-file               :wk "find file")
    ","   '(consult-buffer          :wk "switch buffer")
    "/"   '(consult-ripgrep         :wk "search project")
    ";"   '(execute-extended-command :wk "M-x")
    ":"   '(eval-expression         :wk "eval-expression")
    "x"   '(scratch-buffer          :wk "scratch")

    "b"   '(:ignore t :wk "buffer")
    "b b" '(consult-buffer          :wk "switch")
    "b d" '(kill-current-buffer     :wk "kill")
    "b k" '(kill-buffer             :wk "kill (pick)")
    "b r" '(revert-buffer-quick     :wk "revert")
    "b s" '(save-buffer             :wk "save")

    "f"   '(:ignore t :wk "file")
    "f f" '(find-file               :wk "find")
    "f r" '(consult-recent-file     :wk "recent")
    "f s" '(save-buffer             :wk "save")
    "f p" `(,(lambda () (interactive) (find-file user-init-file)) :wk "init.el")

    "F"   '(:ignore t :wk "frame")
    "F n" '(make-frame-command      :wk "new")
    "F p" '(my/project-switch-in-new-frame :wk "new for project")
    "F t" '(tear-off-window         :wk "tear off window → frame")
    "F d" '(delete-frame            :wk "delete")
    "F o" '(other-frame             :wk "other")
    "F O" '(other-frame-prefix      :wk "next cmd in other frame")
    "F r" '(set-frame-name          :wk "rename")
    "F b" '(beframe-switch-buffer   :wk "switch buf (frame-scoped)")
    "F a" '(beframe-assume-frame-buffers :wk "assume buffers from…")
    "F u" '(beframe-unassume-frame-buffers :wk "unassume buffers")

    "p"   '(:ignore t :wk "project")
    "p p" '(project-switch-project  :wk "switch")
    "p f" '(project-find-file       :wk "find file")
    "p b" '(project-switch-to-buffer :wk "buffer")
    "p d" '(project-dired           :wk "dired")
    "p k" '(project-kill-buffers    :wk "kill buffers")
    "p c" '(project-compile         :wk "compile")
    "p t" '(dired-sidebar-toggle-sidebar :wk "sidebar")

    "g"   '(:ignore t :wk "git")
    "g g" '(magit-status            :wk "status")
    "g b" '(magit-blame             :wk "blame")
    "g l" '(magit-log-buffer-file   :wk "log file")
    "g d" '(magit-diff-buffer-file  :wk "diff file")

    "s"   '(:ignore t :wk "search")
    "s s" '(consult-line            :wk "in buffer")
    "s p" '(consult-ripgrep         :wk "in project")
    "s i" '(consult-imenu           :wk "imenu")
    "s y" '(consult-yasnippet       :wk "snippet")

    ;; In-frame splits are out — niri does the tiling. SPC w v / w s spawn a
    ;; new frame instead, so "side by side" means two niri-managed windows.
    ;; SPC F t still tears off any in-frame popup that slipped through.
    "w"   '(:ignore t :wk "window")
    "w w" '(other-window            :wk "other")
    "w s" '(make-frame-command      :wk "new frame")
    "w v" '(make-frame-command      :wk "new frame")
    "w d" '(delete-window           :wk "delete")
    "w o" '(delete-other-windows    :wk "only")

    "h"   '(:ignore t :wk "help")
    "h f" '(helpful-callable        :wk "function")
    "h v" '(helpful-variable        :wk "variable")
    "h k" '(helpful-key             :wk "key")
    "h m" '(describe-mode           :wk "mode")
    "h ." '(helpful-at-point        :wk "at point")

    "o"   '(:ignore t :wk "open")
    "o t" '(vterm                   :wk "terminal")
    "o d" '(dired-sidebar-toggle-sidebar :wk "sidebar")
    "o m" '(magit-status            :wk "magit")

    "t"   '(:ignore t :wk "toggle")
    "t t" '(consult-theme           :wk "theme")
    "t l" '(display-line-numbers-mode :wk "line numbers")
    "t w" '(visual-line-mode        :wk "wrap")
    "t s" '(flyspell-mode           :wk "spell")
    "t o" '(olivetti-mode           :wk "olivetti (center)")

    "a"   '(:ignore t :wk "ai / claude")
    "a a" '(claude-code-ide-menu             :wk "claude menu")
    "a s" '(claude-code-ide                  :wk "start session")
    "a w" '(claude-code-ide-switch-to-buffer :wk "switch to claude buf")
    "a r" '(claude-code-ide-send-prompt      :wk "send prompt")
    "a c" '(claude-code-ide-continue         :wk "continue last")
    "a R" '(claude-code-ide-resume           :wk "resume session")
    "a l" '(claude-code-ide-list-sessions    :wk "list sessions")
    "a q" '(claude-code-ide-stop             :wk "stop session")

    "c"   '(:ignore t :wk "code")
    "c a" '(eglot-code-actions      :wk "actions")
    "c r" '(eglot-rename            :wk "rename")
    "c f" '(eglot-format            :wk "format")
    "c d" '(xref-find-definitions   :wk "definition")
    "c R" '(xref-find-references    :wk "references")
    "c e" '(consult-flymake         :wk "diagnostics")

    "m"   '(:ignore t :wk "mail")
    "m m" '(mu4e                    :wk "mu4e")
    "m c" '(mu4e-compose-new        :wk "compose")

    "q"   '(:ignore t :wk "quit")
    "q q" '(save-buffers-kill-emacs :wk "save & quit")
    "q f" '(delete-frame            :wk "frame"))

  ;; Belt-and-suspenders: also bind SPC to the leader map directly in evil's
  ;; state maps. `:keymaps 'override' above puts the binding in
  ;; `general-override-mode-map', which sometimes loses priority to evil's
  ;; default motion bindings — when that happens, SPC falls through to
  ;; `evil-forward-char' and signals "End of line" instead of opening the leader.
  (dolist (map (list evil-normal-state-map
                     evil-visual-state-map
                     evil-motion-state-map))
    (define-key map (kbd "SPC") my/leader-map)))

;;; keys.el ends here
