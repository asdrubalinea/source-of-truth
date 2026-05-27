;; Vendored + extended from github:mattwparas/helix-config cogs/recentf.scm.
;; Changes vs upstream:
;;  - Store lives OUTSIDE the project tree: per-project history under the XDG
;;    state dir, keyed by repo root. Nothing is ever written into the working
;;    tree, so no .gitignore entry is ever needed. The path is resolved once
;;    via a single `sh -c` (Steel exposes no env-var reader, and this also
;;    handles $XDG_STATE_HOME defaulting, the git-root lookup and `mkdir -p` in
;;    one place). Falls back to ".helix/recent-files.txt" only if that fails.
;;  - Lazy + deferred I/O: the store path is resolved, and the on-disk list is
;;    read, on first use rather than at module load — so no subprocess/IO runs
;;    while helix is still loading config. recentf-init schedules the first
;;    snapshot a few seconds in; it then reschedules itself every ~2 min.
;;  - Writes are atomic (temp file + rename) and every read/write is wrapped in
;;    with-handler, so a corrupt store, a read-only dir, or a missing tool can
;;    never throw at startup or stall the snapshot loop — worst case the list
;;    is skipped, not lost-and-broken.
;;  - recentf-open-files shows recent files FIRST, then every other file in the
;;    workspace (via `git ls-files`, gitignore-aware), as one native picker.
;;    `core.quotePath=false` keeps non-ASCII filenames intact. Outside a git
;;    repo the workspace list is empty (the native picker on `space F` covers
;;    that case).
;;  - take-at-most replaces `take` so a list shorter than the cap can't error.
;; Persistence format is upstream's: one write-line!'d path per line; read!
;; reads them all back as a list of strings.

(require "helix/editor.scm")
(require "helix/misc.scm")
(require (prefix-in helix.static. "helix/static.scm"))
(require-builtin steel/process)
(require "steel/result")

(provide refresh-files
         flush-recent-files
         recentf-open-files
         recentf-snapshot
         recentf-init
         get-recent-files
         recentf-store-path)

(define MAX-FILE-COUNT 25)

;; --- store location -------------------------------------------------------

;; Resolves the absolute store path and ensures its directory exists, all in
;; one shell call. helix's cwd is passed as $1; the repo root (or that cwd,
;; outside a repo) is path-escaped into the filename so every project gets its
;; own list and subdirectories of one project share it. $ and {} are literal
;; here — Steel does not interpolate.
(define STORE-RESOLVER
  (string-append
   "base=\"${XDG_STATE_HOME:-$HOME/.local/state}/helix/recentf\"\n"
   "mkdir -p \"$base\" 2>/dev/null\n"
   "root=\"$(git -C \"$1\" rev-parse --show-toplevel 2>/dev/null || printf %s \"$1\")\"\n"
   "key=\"$(printf %s \"$root\" | sed 's#/#%#g')\"\n"
   "printf %s \"$base/$key.txt\""))

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

(define *store-path* #false)

;; Resolved lazily and memoised — the first call spawns the resolver, passing
;; helix's cwd as $1 (same cwd the picker lists files from).
(define (recentf-store-path)
  (unless *store-path*
    (let ([p (trim (capture "sh"
                            (list "-c" STORE-RESOLVER "sh"
                                  (helix.static.get-helix-cwd))))])
      (set! *store-path* (if (equal? p "") ".helix/recent-files.txt" p))))
  *store-path*)

;; --- in-memory list -------------------------------------------------------

(define *recent-files* '())
(define *loaded?* #false)

;; The file holds each path on its own line; read! reads all datums back as a
;; list. Guarded against missing/empty/garbled/unreadable stores → '().
(define (read-recent-files path)
  (with-handler
   (lambda (_err) '())
   (if (path-exists? path)
       (let ([contents (call-with-input-file path
                                             (lambda (f) (read-port-to-string f)))])
         (if (equal? (trim contents) "")
             '()
             (let ([data (read! contents)])
               (if (list? data) (filter string? data) '()))))
       '())))

(define (ensure-loaded!)
  (unless *loaded?*
    (set! *recent-files* (read-recent-files (recentf-store-path)))
    (set! *loaded?* #true)))

(define (get-recent-files)
  (ensure-loaded!)
  *recent-files*)

(define (remove-duplicates lst)
  (define (remove-duplicates-via-hash lst accum set)
    (cond
      [(null? lst) accum]
      [else
       (let ([elem (car lst)])
         (if (hashset-contains? set elem)
             (remove-duplicates-via-hash (cdr lst) accum set)
             (remove-duplicates-via-hash (cdr lst) (cons elem accum) (hashset-insert set elem))))]))
  (reverse (remove-duplicates-via-hash lst '() (hashset))))

;; Like `take`, but clamps instead of erroring when the list is shorter than n.
(define (take-at-most lst n)
  (cond
    [(or (null? lst) (<= n 0)) '()]
    [else (cons (car lst) (take-at-most (cdr lst) (- n 1)))]))

(define (refresh-files)
  (ensure-loaded!)
  (let* ([document-ids (editor-all-documents)]
         [currently-opened-files
          (filter string? (map editor-document->path document-ids))])
    ;; currently-open buffers first, then existing history; dedup; cap.
    (set! *recent-files*
          (take-at-most (remove-duplicates (append currently-opened-files *recent-files*))
                        MAX-FILE-COUNT))))

;; Atomic + guarded: write the whole list to a temp file, then rename over the
;; store, so a crash mid-write can never leave a half-written (unparseable)
;; file. A failure (e.g. read-only dir) is swallowed rather than thrown.
(define (flush-recent-files)
  (with-handler
   (lambda (_err) '())
   (let* ([path (recentf-store-path)]
          [dir (parent-name path)]
          [tmp (string-append path ".tmp")])
     (when (and (string? dir) (not (equal? dir "")) (not (path-exists? dir)))
       (create-directory! dir))
     (call-with-port (open-output-file tmp #:exists 'truncate)
                     (lambda (output-file)
                       (for-each (lambda (line) (write-line! output-file line))
                                 *recent-files*)))
     (rename-file-or-directory! tmp path))))

;; --- workspace files ------------------------------------------------------

;; Every gitignore-respecting file under helix's cwd, as absolute paths.
;; `git -C cwd ls-files` lists tracked + untracked (ignored excluded) relative
;; to cwd; we prefix cwd so they dedup against the (absolute) recent list.
;; `core.quotePath=false` keeps unicode/space filenames intact. Outside a repo
;; git fails and capture yields "" → '().
(define (lines->absolute cwd s)
  (map (lambda (rel) (string-append cwd "/" rel))
       (filter (lambda (x) (not (equal? x "")))
               (split-many s "\n"))))

(define (all-workspace-files)
  (let ([cwd (helix.static.get-helix-cwd)])
    (lines->absolute
     cwd
     (capture "git"
              (list "-C" cwd "-c" "core.quotePath=false"
                    "ls-files" "--cached" "--others" "--exclude-standard")))))

(define (helix-picker! pick-list)
  (push-component! (picker pick-list)))

;; Recent files first, then all other workspace files. The native picker
;; preserves this order while the query is empty, and fuzzy-matches across
;; everything once you type.
(define (recentf-open-files)
  (refresh-files)
  (helix-picker!
   (remove-duplicates (append *recent-files* (all-workspace-files)))))

;; --- snapshot loop --------------------------------------------------------

;; Snapshot the visited files to disk, then reschedule ~every 2 minutes.
(define (recentf-snapshot)
  (refresh-files)
  (flush-recent-files)
  (enqueue-thread-local-callback-with-delay (* 1000 60 2) recentf-snapshot))

;; Called from init.scm: defer the first snapshot a few seconds so all
;; subprocess/IO happens well after editor startup, never during config load.
(define (recentf-init)
  (enqueue-thread-local-callback-with-delay (* 1000 5) recentf-snapshot))
