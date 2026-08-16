# Window rules for the mango layer, one `windowrule=` line each.
#
# The niri layer's rules live in ../niri/window-rules.nix and are deliberately NOT
# shared: the two dialects only overlap in the middle. mango has isglobal /
# shield_when_capture / isnamedscratchpad with no niri equivalent; niri has
# block-out-from / clip-to-geometry / tab-indicator with no mango equivalent. A
# neutral vocabulary could only express the intersection, so both files are
# hand-written and the overlap (~10 apps) is duplicated on purpose. When you add
# an app to one, add it to the other.
#
# Syntax: windowrule=key:value,key:value,… — `appid` and `title` are the matchers,
# both regex, and if both are given BOTH must match. Fractions below 1 in
# width/height are a proportion of the screen; ≥1 is pixels.
[
  # --- Privacy -------------------------------------------------------------
  # niri's `block-out-from = "screencast"`. Same intent: the window renders
  # normally on the panel but is blanked in anything capturing the screen.
  "appid:^org\\.telegram\\.desktop$,shield_when_capture:1"
  "appid:^app\\.drey\\.PaperPlane$,shield_when_capture:1"

  # --- Scratchpads ---------------------------------------------------------
  # Native named scratchpads: the rule marks the window as a scratchpad tenant and
  # sizes it; the toggle key (and the command that launches it on first use) is in
  # ./mango.nix. This is what ADR-0006's nirius daemon exists to emulate under
  # niri — mango needs neither the daemon nor the two shell scripts.
  #
  # Geometry mirrors the niri rules: Telegram ~55%×85%, terminal 90%×90%, both
  # proportional so they adapt to whichever output they land on.
  "appid:^org\\.telegram\\.desktop$,isnamedscratchpad:1,width:0.55,height:0.85"
  "appid:^scratchpad-terminal$,isnamedscratchpad:1,width:0.9,height:0.9"

  # --- Picture-in-Picture --------------------------------------------------
  # isglobal is the whole reason the niri layer's pip-follow.nix has no
  # counterpart here: mango can genuinely show one window on every tag, so the PiP
  # needs no daemon chasing it across workspaces.
  #
  # offsetx/offsety are percentages from CENTRE, where 100 is the screen edge
  # inside the outer gap — so 96,96 is a small inset from the bottom-right,
  # standing in for niri's fixed 32px offset. 480x270 is the same fixed size.
  "appid:^(firefox|zen)$,title:^Picture-in-Picture$,isfloating:1,isglobal:1,width:480,height:270,offsetx:96,offsety:96"
  "title:^Picture in picture$,isfloating:1,isglobal:1,offsetx:96,offsety:96"
  "title:^Discord Popout$,isfloating:1,offsetx:96,offsety:96"

  # --- Screensaver ---------------------------------------------------------
  # drift takes the whole output and must be focused, or the first keypress goes
  # to whatever was underneath instead of dismissing it.
  "appid:^drift-screensaver$,isfullscreen:1"

  # --- Dialogs and transients ---------------------------------------------
  # The niri file spells these out one rule per app-id / per title. mango matches
  # by regex, so the same set collapses into two alternations. Keep them sorted;
  # adding an entry is editing one string.
  "appid:^(dialog|popup|task_dialog|gcr-prompter|pinentry|file-roller|org\\.gnome\\.FileRoller|nm-connection-editor|xdg-desktop-portal-gtk|org\\.kde\\.polkit-kde-authentication-agent-1|io\\.github\\.fsobolev\\.Cavalier)$,isfloating:1"
  "title:^(Progress|File Operations|Copying|Moving|Properties|Downloads|file progress|Confirm|Authentication Required|Notice|Warning|Error)$,isfloating:1"

  # --- Emacs popup frames --------------------------------------------------
  # display-buffer-alist in desktop/emacs/init.el opens magit/*Help*/vterm frames
  # with a `popup:` title prefix. niri gives them a fixed 1100px column; the
  # scroller layout has no pixel widths, only a proportion of the output, so this
  # is 1100/2560 on the panel these were tuned for.
  "appid:^emacs$,title:^popup:,scroller_proportion:0.45"
]
