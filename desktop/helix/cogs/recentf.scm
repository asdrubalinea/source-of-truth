;; Vendored + extended from github:mattwparas/helix-config cogs/recentf.scm.
;; Changes vs upstream:
;;  - RECENTF-FILE is cwd-relative (".helix/recent-files.txt"), so history is
;;    per-project. We bake the relative path into the cog (rather than calling
;;    set-recent-file-location! from init.scm) because helix reads *recent-files*
;;    at module-load, before init.scm runs.
;;  - recentf-open-files shows recent files FIRST, then every other file in the
;;    workspace (via `git ls-files`, gitignore-aware), as one native picker. It
;;    refreshes from the open buffers first, so it is never stale, and hides the
;;    store itself (anything under .helix/).
;;  - read/flush are guarded with `filter string?`/`list?` so a missing or
;;    garbled store yields '() instead of polluting the picker. (Persistence
;;    format is upstream's: one write-line!'d path per line, read! reads them
;;    all back as a list of strings.)

(require "helix/editor.scm")
(require "helix/misc.scm")
(require (prefix-in helix.static. "helix/static.scm"))
(require-builtin steel/process)
(require "steel/result")

(provide refresh-files
         flush-recent-files
         recentf-open-files
         recentf-snapshot
         get-recent-files
         set-recent-file-location!)

(define MAX-FILE-COUNT 25)

;; Relative to helix's cwd → one history file per project.
(define RECENTF-FILE ".helix/recent-files.txt")
(define RECENTF-DIR ".helix")

(define (set-recent-file-location! path)
  (set! RECENTF-FILE path))

;; The file holds each path on its own line, written with write-line! (which
;; emits the quoted `write` form). read! reads *all* datums back as a list of
;; strings. Guarded so a missing/garbled file yields '().
(define (read-recent-files)
  (if (path-exists? RECENTF-FILE)
      (let ([contents (call-with-input-file RECENTF-FILE
                                            (lambda (f) (read-port-to-string f)))])
        (if (equal? (trim contents) "")
            '()
            (let ([data (read! contents)])
              (if (list? data) (filter string? data) '()))))
      '()))

(define *recent-files* (read-recent-files))

(define (get-recent-files)
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

(define (refresh-files)
  (let* ([document-ids (editor-all-documents)]
         [currently-opened-files
          (filter string? (map (lambda (doc-id) (editor-document->path doc-id)) document-ids))])
    ;; currently-open buffers first, then existing history; dedup; cap.
    (let* ([full-list (append currently-opened-files *recent-files*)]
           [deduped (remove-duplicates full-list)])
      (set! *recent-files* (take deduped MAX-FILE-COUNT)))))

(define (flush-recent-files)
  (unless (path-exists? RECENTF-DIR)
    (create-directory! RECENTF-DIR))
  (call-with-port (open-output-file RECENTF-FILE #:exists 'truncate)
                  (lambda (output-file)
                    (map (lambda (line)
                           (when (string? line)
                             (write-line! output-file line)))
                         *recent-files*))))

;; Every gitignore-respecting file under helix's cwd, as absolute paths.
;; `git ls-files` lists tracked + untracked (excluding ignored) relative to the
;; cwd; we prefix the cwd so they dedup cleanly against the (absolute) recent
;; list. In a non-git directory git exits with empty stdout, yielding '().
(define (lines->absolute cwd s)
  (map (lambda (rel) (string-append cwd "/" rel))
       (filter (lambda (x) (not (equal? x "")))
               (split-many s "\n"))))

(define (all-workspace-files)
  (let ([cwd (helix.static.get-helix-cwd)]
        [spawned (~> (command "git"
                              (list "ls-files" "--cached" "--others" "--exclude-standard"))
                     with-stdout-piped
                     ;; pipe (and discard) stderr too, else git's "not a git
                     ;; repository" message leaks into the terminal.
                     with-stderr-piped
                     spawn-process)])
    (if (Ok? spawned)
        (let ([out (wait->stdout (unwrap-ok spawned))])
          (if (Ok? out)
              (lines->absolute cwd (unwrap-ok out))
              '()))
        '())))

(define (helix-picker! pick-list)
  (push-component! (picker pick-list)))

;; Drop the per-project store (and anything else under .helix/) from the list.
(define (not-in-helix-dir? path)
  (= 1 (length (split-many path "/.helix/"))))

;; Recent files first, then all other workspace files. The native picker
;; preserves this order while the query is empty, and fuzzy-matches across
;; everything once you type.
(define (recentf-open-files)
  (refresh-files)
  (helix-picker!
   (filter not-in-helix-dir?
           (remove-duplicates (append *recent-files* (all-workspace-files))))))

;; Runs every 2 minutes, snapshotting the visited files to disk.
(define (recentf-snapshot)
  (refresh-files)
  (flush-recent-files)
  (enqueue-thread-local-callback-with-delay (* 1000 60 2) recentf-snapshot))
