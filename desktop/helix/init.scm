;; The recent-files command is defined in helix.scm (so it is documented and
;; registered first). Here we just start the background snapshot that persists
;; the visited-files list (~every 2 min).
(require (only-in "cogs/recentf.scm" recentf-snapshot))

(recentf-snapshot)
