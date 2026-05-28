;; The recent-files command is defined in helix.scm (so it is documented and
;; registered first). Here we kick off the background snapshot that persists
;; the visited-files list (~every 2 min). recentf-init only schedules a delayed
;; callback, so no file/subprocess work happens during config load.
(require "helix/keymaps.scm") ;; provides the `keymap` macro used below
(require (only-in "cogs/recentf.scm" recentf-init))
(require (only-in "helix.scm" recent-files))

;; Bind space f here (not in helix.nix's TOML keymap): only the Steel `keymap`
;; macro routes through keymap-update-documentation!, which copies recent-files'
;; ;;@doc into the keymap infobox. A TOML binding would show "Undocumented
;; plugin command" instead.
(keymap (global)
        (normal (space (f ":recent-files"))))

(recentf-init)
