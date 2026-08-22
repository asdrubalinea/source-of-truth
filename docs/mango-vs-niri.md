# mango vs niri, in the ember rice

Both are compositor layers of the same rice (`rices/ember/compositors/`), both
installed at once, session picked at the tuigreet menu per login. This is the
map between them while the muscle memory is split. See
`docs/adr/0012-one-rice-two-compositors.md` for why.

Delete this file when one of the two wins.

## Keys

Identical unless the right column says otherwise.

| Key | niri | mango |
| --- | --- | --- |
| Mod+Return | wezterm | same |
| Mod+Shift+Return | terminal scratchpad | same key, native scratchpad |
| Mod+Space | Noctalia launcher | same |
| Mod+B / Mod+P / Mod+N | blueman / pavucontrol / dolphin | same |
| Mod+L | `loginctl lock-session` | same |
| Mod+Shift+B | zen-beta | same |
| Mod+Y | mpv on the clipboard URL | same |
| Mod+T | Telegram scratchpad | same key, native scratchpad |
| Mod+Shift+T | toggle scratchpad pile | `toggle_scratchpad` |
| Mod+Q | close window | `killclient` |
| Mod+F | fullscreen | `togglefullscreen` |
| Mod+M | maximize column | `togglemaximizescreen` |
| Mod+←/→ | focus column left/right | `focusdir` — same feel, scroller strip |
| Mod+↑/↓ | focus window up/down in column | `focusdir` — the scroller stack |
| Mod+Shift+arrows | move column/window | `exchange_client` |
| Mod+1..0 | focus workspace 1..10 | `view` tag 1..10 |
| Mod+Shift+1..0 | move window to workspace | `tag` |
| Mod+E | overview | `toggleoverview` |
| Mod+Shift+Space | center column | `centerwin` |
| Mod+Shift+S / Mod+Shift+D | screenshot region / screen | grim+slurp script, saves to `~/Pictures/Screenshots` and copies |
| Mod+Shift+R | soft-reboot | same |
| Mod+Shift+E | quit | `quit` |
| Volume / media keys | pamixer, playerctl | same |
| **Mod+G** | even split | **nothing** |
| **Mod+O** | audio-output switcher | **nothing** |
| **Brightness keys** | backlight, or DDC/CI when clamshelled | **nothing** — use the Noctalia panel or `brightnessctl` |

## Behaves differently

- **Workspaces are tags.** Ten of them, always present, and a window can be on
  more than one. Nothing disappears when you empty it, and there is no dynamic
  workspace list to scroll past the end of.
- **Scratchpads launch lazily.** The first Mod+T *starts* Telegram; under niri it
  was already running, parked, since login. So the first summon of the session is
  slow and the ones after are instant.
- **The PiP is genuinely sticky** (`isglobal`), rather than being dragged onto
  your current workspace by a daemon a moment after you switch.
- **No marquee.** The portrait OLED's video band is niri-only. The top of that
  panel is ordinary tiling space under mango.
- **Browsers don't force-maximize.** Unnecessary: every scroller column is
  full-width already (`scroller_default_proportion = 1.0`).
- **Emacs popup frames** get 45% of the output instead of a fixed 1100px —
  scroller widths are proportions, not pixels.
- **Killing the compositor does not restart the session.** Under niri it did, and
  safely: niri ships a real `niri.service` (`Type=notify`,
  `BindsTo=`/`Before=graphical-session.target`), and `niri-session` blocks on
  `systemctl --user --wait start niri.service`, then forces the session down with
  `niri-shutdown.target` (`Conflicts=graphical-session.target`) and unsets
  `WAYLAND_DISPLAY`. Compositor death is a systemd event, so every
  `PartOf=graphical-session.target` client is cleanly *stopped* and comes back on
  the next login.

  mango ships no systemd units at all — the only artifact is the passive
  `mango-session.target` home-manager writes, and mango itself is a bare
  greeter-launched process that pokes `systemctl --user start
  mango-session.target` once from `autostart.sh`. Nothing blocks on it and there
  is no shutdown target, so systemd never learns it died:
  `graphical-session.target` stays `active`, and the *replacement* mango's `start`
  is a no-op against an already-active target, so nothing is recycled. Restart
  policies (below) paper over it; the asymmetry itself is unfixed.

## If something looks wrong

- **Bar/notifications/wallpaper missing entirely** → `graphical-session.target`
  never started. mango reaches it through `~/.config/mango/autostart.sh`, which
  the HM module only writes when `autostart_sh` is non-empty. Check
  `systemctl --user status mango-session.target`.
- **Screens never blank at idle** → check `systemctl --user is-active swayidle`
  first (see "Everything died after you restarted mango" below) — a dead idle
  manager is the likelier cause and it reads as `inactive`, not `failed`. If it is
  running, `ember-monitor-power` branches on `$MANGO_INSTANCE_SIGNATURE`; confirm
  it is set in the session (`systemctl --user show-environment`).
- **Window borders are the wrong colour** → Noctalia's own mango colour template
  got enabled. It must stay off; `~/.config/mango/config.conf` is a read-only
  store symlink and colours come from stylix via
  `rices/ember/compositors/mango/mango.nix`.
- **Rebuild fails with a config error from `mango -c … -p`** → that is the point
  of the flake's module: a config key was renamed upstream. Fix the key, not the
  validation.
- **Monitors are misarranged** → still kanshi
  (`homes/tempest/monitors.nix`), same as niri; mango implements
  wlr-output-management, so nothing compositor-specific is involved.
- **Everything died after you restarted mango** → the clients restart-looped
  against the dead socket and hit systemd's stock start limit (5 tries /
  `RestartSec=100ms` / 10s), which lands them in **`inactive`, not `failed`** — so
  `systemctl --user --failed` looks clean while swayidle, kanshi and the idle
  inhibitor are all dead. On 2026-08-19 swayidle sat dead for three hours that
  way: no panel power-off, no idle suspend. noctalia fails differently again — it
  handles display loss gracefully and **exits 0**, so `Restart=on-failure`
  declines and there is not even a restart-job line in the journal.
  `homes/tempest/default.nix` sets `StartLimitIntervalSec=0` + `RestartSec=2` on
  the five session clients, and `rices/ember/noctalia.nix` upgrades noctalia to
  `Restart=always`, so they now reconnect on their own within ~2s of a new mango.
- **Screencast picks the wrong backend under *niri* after this landed** → mango's
  NixOS module pulls in xdg-desktop-portal-wlr system-wide. See risk 3 in ADR
  0012.
