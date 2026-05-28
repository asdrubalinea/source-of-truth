;; Shared store helpers for the recentf + scratch cogs. Both persist per-project
;; state under $XDG_STATE_HOME/helix/<subdir>, keyed by the repo root, and both
;; need to shell out to resolve that path: Steel exposes no env-var reader, so
;; $XDG_STATE_HOME defaulting, the git-root lookup and `mkdir -p` all happen in
;; one `sh -c`. That shell contract plus the subprocess->string helper used to
;; be duplicated byte-for-byte in each cog; they live here once so they can't
;; drift. Imported as a sibling — each cog does `(require "store.scm")`, which
;; Steel resolves next to the cog (see helix.nix on why cogs/ is one symlink).
(require-builtin steel/process)
(require "steel/result")

(provide capture
         resolve-store-path)

;; Run argv, return trimmed stdout (or "" on any failure). stderr is piped and
;; discarded so a tool's diagnostics never leak into the terminal.
(define (capture prog args)
  (with-handler
   (lambda (_err) "")
   (let ([spawned (~> (command prog args)
                      with-stdout-piped
                      with-stderr-piped
                      spawn-process)])
     (if (Ok? spawned)
         (let ([out (wait->stdout (unwrap-ok spawned))])
           (if (Ok? out) (unwrap-ok out) ""))
         ""))))

;; The shell program both cogs run: print an absolute store path under
;; $XDG_STATE_HOME/helix/<subdir>, named after the repo root of $1 (helix's cwd)
;; with `/` escaped to `%`, so every project gets its own file and subdirectories
;; of one project share it. Outside a repo the cwd itself is keyed. When touch?
;; is set the file is created if missing (so `helix.open` lands on a real path).
;; $ and {} are literal here — Steel does not interpolate.
(define (store-resolver subdir ext touch?)
  (string-append
   "base=\"${XDG_STATE_HOME:-$HOME/.local/state}/helix/" subdir "\"\n"
   "mkdir -p \"$base\" 2>/dev/null\n"
   "root=\"$(git -C \"$1\" rev-parse --show-toplevel 2>/dev/null || printf %s \"$1\")\"\n"
   "key=\"$(printf %s \"$root\" | sed 's#/#%#g')\"\n"
   "path=\"$base/$key." ext "\"\n"
   (if touch? "[ -f \"$path\" ] || : > \"$path\"\n" "")
   "printf %s \"$path\""))

;; Resolve (and trim) the absolute store path for subdir/ext, passing helix's
;; cwd as $1. Returns "" on any failure — each caller supplies its own fallback.
(define (resolve-store-path cwd subdir ext touch?)
  (trim (capture "sh" (list "-c" (store-resolver subdir ext touch?) "sh" cwd))))
