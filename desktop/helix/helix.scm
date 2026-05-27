;; Loaded before init.scm; functions provided here become :typed-commands,
;; and their ;;@doc strings show in the keymap (so `space f` is documented and
;; registered before the first keypress).
(require "helix/editor.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require (only-in "cogs/recentf.scm" recentf-open-files))

(provide recent-files open-init-scm open-helix-scm)

;;@doc
;; Open recently edited files first, then all other workspace files
(define (recent-files)
  (recentf-open-files))

;;@doc
;; Open init.scm
(define (open-init-scm) (helix.open (helix.static.get-init-scm-path)))

;;@doc
;; Open helix.scm
(define (open-helix-scm) (helix.open (helix.static.get-helix-scm-path)))
