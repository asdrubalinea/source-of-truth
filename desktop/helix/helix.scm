;; Loaded before init.scm; functions provided here become :typed-commands, and
;; their ;;@doc strings power the :command completion popup. NOTE: that doc does
;; NOT reach the keymap infobox on its own — a key must be bound via the Steel
;; `keymap` macro (see init.scm) for its ;;@doc to show there; a binding in
;; helix.nix's TOML keymap renders as "Undocumented plugin command".
(require "helix/editor.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require (only-in "cogs/recentf.scm" recentf-open-files))
(require (only-in "cogs/scratch.scm" scratch-open))

(provide recent-files
         open-init-scm
         open-helix-scm
         scratch)

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

;;@doc
;; Open this project's persistent scratch buffer (XDG state, per repo)
(define (scratch) (scratch-open))
