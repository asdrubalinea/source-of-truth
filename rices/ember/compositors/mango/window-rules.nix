# Window rules for the mango layer, one `windowrule=` line each.
#
# NOT shared with ../niri/window-rules.nix: the two dialects only overlap in the
# middle (mango has isglobal/shield_when_capture/isnamedscratchpad, niri has
# block-out-from/clip-to-geometry/tab-indicator), so a neutral vocabulary could
# express only the intersection. Both files are hand-written and the ~10-app
# overlap is duplicated on purpose — ADD AN APP TO ONE, ADD IT TO THE OTHER.
#
# Syntax: windowrule=key:value,… — `appid` and `title` are both regex matchers,
# and if both are given BOTH must match. Fractions below 1 in width/height are a
# proportion of the screen; ≥1 is pixels.
[
  # --- Privacy -------------------------------------------------------------
  # niri's `block-out-from = "screencast"`. Same intent: the window renders
  # normally on the panel but is blanked in anything capturing the screen.
  "appid:^org\\.telegram\\.desktop$,shield_when_capture:1"
  "appid:^app\\.drey\\.PaperPlane$,shield_when_capture:1"

  # --- Scratchpads ---------------------------------------------------------
  # Native: the rule marks the window a scratchpad tenant and sizes it, the
  # toggle key is in ./mango.nix. This is what ADR 0006's nirius daemon exists to
  # emulate under niri — mango needs neither it nor the two shell scripts.
  # Geometry mirrors the niri rules, proportional so it adapts to any output.
  "appid:^org\\.telegram\\.desktop$,isnamedscratchpad:1,width:0.55,height:0.85"
  "appid:^scratchpad-terminal$,isnamedscratchpad:1,width:0.9,height:0.9"

  # --- Instrument panel ----------------------------------------------------
  # Mod+I, a floating and transient `sitrep` (rices/ember/sitrep-hud.nix). Not a
  # scratchpad in either layer: it is respawned per invocation so the numbers are
  # never stale. Geometry mirrors the niri rule.
  "appid:^sitrep-hud$,isfloating:1,width:0.6,height:0.85"

  # --- Picture-in-Picture --------------------------------------------------
  # isglobal is why pip-follow.nix has no counterpart here: mango can genuinely
  # show one window on every tag, so the PiP needs no daemon chasing it.
  # offsetx/offsety are percentages from CENTRE where 100 is the screen edge
  # inside the outer gap, so 96,96 stands in for niri's fixed 32px offset.
  "appid:^(firefox|zen)$,title:^Picture-in-Picture$,isfloating:1,isglobal:1,width:480,height:270,offsetx:96,offsety:96"
  "title:^Picture in picture$,isfloating:1,isglobal:1,offsetx:96,offsety:96"
  "title:^Discord Popout$,isfloating:1,offsetx:96,offsety:96"

  # --- Screensaver ---------------------------------------------------------
  # drift takes the whole output and must be focused, or the first keypress goes
  # to whatever was underneath instead of dismissing it.
  "appid:^drift-screensaver$,isfullscreen:1"

  # --- Dialogs and transients ---------------------------------------------
  # The niri file spells these out one rule each; mango matches by regex, so the
  # same set collapses into two alternations. Keep them sorted.
  "appid:^(dialog|popup|task_dialog|gcr-prompter|pinentry|file-roller|org\\.gnome\\.FileRoller|nm-connection-editor|xdg-desktop-portal-gtk|org\\.kde\\.polkit-kde-authentication-agent-1|io\\.github\\.fsobolev\\.Cavalier)$,isfloating:1"
  "title:^(Progress|File Operations|Copying|Moving|Properties|Downloads|file progress|Confirm|Authentication Required|Notice|Warning|Error)$,isfloating:1"

  # --- Emacs popup frames --------------------------------------------------
  # display-buffer-alist opens magit/*Help*/vterm frames with a `popup:` title
  # prefix. The scroller has no pixel widths, only a proportion of the output, so
  # niri's fixed 1100px column becomes 1100/2560 on the panel these were tuned on.
  "appid:^emacs$,title:^popup:,scroller_proportion:0.45"
]
