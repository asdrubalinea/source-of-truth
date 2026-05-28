;; Per-project scratch buffer. `(scratch-open)` opens
;; $XDG_STATE_HOME/helix/scratch/<repo>.md so notes survive restarts and stay
;; out of the working tree. The store path is resolved by the shared per-repo
;; resolver in cogs/store.scm (see that file for the XDG location / repo-root
;; keying / fail-soft rationale); it's created if missing so `helix.open` lands
;; on a real path rather than prompting. Subdirectories of one repo share the
;; same scratch; outside a repo the cwd itself is keyed.

(require "helix/editor.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require (only-in "store.scm" resolve-store-path))

(provide scratch-open)

(define *scratch-path* #false)

(define (scratch-path)
  (unless *scratch-path*
    (let ([p (resolve-store-path (helix.static.get-helix-cwd) "scratch" "md" #true)])
      (set! *scratch-path* (if (equal? p "") #false p))))
  *scratch-path*)

(define (scratch-open)
  (let ([p (scratch-path)])
    (when (string? p) (helix.open p))))
