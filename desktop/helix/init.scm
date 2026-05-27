;; The recent-files command is defined in helix.scm (so it is documented and
;; registered first). Here we kick off the background snapshot that persists
;; the visited-files list (~every 2 min). recentf-init only schedules a delayed
;; callback, so no file/subprocess work happens during config load.
(require (only-in "cogs/recentf.scm" recentf-init))

(recentf-init)
