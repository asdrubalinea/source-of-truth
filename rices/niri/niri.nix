{ config
, pkgs
, inputs
, lib
, ...
}:
let
  windowRules = import ./window-rules.nix;
  c = config.lib.stylix.colors.withHashtag;

  # --- Scratchpads (nirius-backed) -----------------------------------------
  # A scratchpad pops a window onto the focused workspace and dismisses it with
  # the same key. niri has no truly hidden workspace, so the "scratchpad" is the
  # bottom-most workspace; niriusd tracks which windows belong to it and nirius
  # flips them in/out. See docs/adr/0006-niri-scratchpad-via-nirius.md. Geometry
  # (float + size) lives in window-rules.nix, matched per app-id.
  # The `niri` CLI and the running compositor MUST come from the same package.
  # `niri msg` refuses to talk to a different version: it prints "Running niri
  # compositor has a different version from the niri CLI" on stdout *instead of*
  # the JSON, so `--json` consumers silently get a jq parse error and every
  # script here misreads the session. The compositor is the SYSTEM one —
  # greetd launches `niri-session` from /run/current-system/sw (see
  # rices/niri/system.nix `programs.niri.enable`, and the niri.service unit ships
  # inside that same package) — and niri-flake's default there is niri-stable.
  # So: niri-stable, not niri-unstable. Bumping the compositor means changing
  # both the system's `programs.niri.package` and this line together.
  niri = "${pkgs.niri-stable}/bin/niri";
  jq = "${pkgs.jq}/bin/jq";
  nirius = "${pkgs.nirius}/bin/nirius";
  sleep = "${pkgs.coreutils}/bin/sleep";

  # --- Brightness (Mod brightness keys) ------------------------------------
  # One control, two backends. When the internal panel is an active niri output,
  # adjust its backlight with brightnessctl (laptop use). When clamshell-docked
  # (eDP-1 disabled) there is no backlight — brightness on an external (esp. the
  # emissive QD-OLED) goes over DDC/CI with ddcutil (VCP 0x10). The else-branch
  # fires for ANY clamshell profile; ddcutil only succeeds on externals that
  # expose DDC/CI (needs hardware.i2c.enable in hosts/tempest/hardware.nix). Tune
  # --sleep-multiplier / add --display on arrival via `ddcutil detect`. See
  # docs/adr/0009.
  brightnessAdjust = pkgs.writeShellScript "brightness-adjust" ''
    set -u
    dir="''${1:-up}"
    step=5
    if ${niri} msg --json outputs | ${jq} -e '(."eDP-1".logical // null) != null' >/dev/null 2>&1; then
      case "$dir" in
        up)   exec ${pkgs.brightnessctl}/bin/brightnessctl set "$step%+" ;;
        down) exec ${pkgs.brightnessctl}/bin/brightnessctl set "$step%-" ;;
      esac
    else
      case "$dir" in
        up)   exec ${pkgs.ddcutil}/bin/ddcutil --sleep-multiplier 2 setvcp 10 + "$step" ;;
        down) exec ${pkgs.ddcutil}/bin/ddcutil --sleep-multiplier 2 setvcp 10 - "$step" ;;
      esac
    fi
  '';

  # --- Audio output switcher (Mod+O) ---------------------------------------
  # A name-based picker for the default output device, so switching speakers ↔
  # AirPods ↔ dock survives reboots (PipeWire node *ids* are reassigned, but wpctl
  # persists the choice by stable node name). We enumerate live Audio/Sink nodes and
  # hide EasyEffects' virtual "easyeffects_sink" (picking it as default is meaningless
  # — apps already feed it). Setting the default to a real device is the trigger
  # EasyEffects watches: it routes its pipeline there and its per-route autoload swaps
  # the speaker preset in/out for free (see homes/tempest/speakers.nix). The currently
  # configured default (PipeWire's default.configured.audio.sink — what the last pick
  # wrote) is marked with a ● so the menu reflects present state. Sinks with no
  # node.description are skipped (no usable label); duplicate descriptions get a "(n)"
  # suffix so each visible row maps back to exactly one id. Portable: shows whatever
  # sinks the host has, no-ops when there are none.
  pwDump = "${pkgs.pipewire}/bin/pw-dump";
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  tofiBin = "${pkgs.tofi}/bin/tofi";
  gawk = "${pkgs.gawk}/bin/gawk";
  audioOutputSwitcher = pkgs.writeShellScript "audio-output-switcher" ''
    set -euo pipefail

    dump=$(${pwDump})

    # node.name of the configured default sink (what `wpctl set-default` wrote);
    # empty if unset. Used only to mark the current row.
    current=$(printf '%s' "$dump" | ${jq} -r '
      first(
        .[]
        | select(.type == "PipeWire:Interface:Metadata")
        | select(.props["metadata.name"] == "default")
        | (.metadata // [])[]
        | select(.key == "default.configured.audio.sink")
        | .value.name?
      ) // empty
    ')

    # One line per real sink: "id<TAB>node.name<TAB>description". Hide EasyEffects'
    # virtual sink and any sink without a description (it would have no usable label).
    sinks=$(printf '%s' "$dump" | ${jq} -r '
      .[]
      | select(.type == "PipeWire:Interface:Node")
      | select(.info.props["media.class"] == "Audio/Sink")
      | select(.info.props["node.name"] != "easyeffects_sink")
      | select(.info.props["node.description"] != null)
      | "\(.id)\t\(.info.props["node.name"])\t\(.info.props["node.description"])"
    ')
    [ -n "$sinks" ] || exit 0

    # Shared label routine, run twice over the same $sinks so both passes build
    # identical rows: mode=show prints the menu, mode=resolve prints the id of the
    # selected row. The configured default gets a ● prefix; duplicate descriptions
    # get a "(n)" suffix so each row maps to exactly one id. Non-current rows carry
    # no leading whitespace, so a picker that trims the returned line can't break
    # the round-trip.
    mklabel='
      { seen[$3]++
        label = $3
        if (seen[$3] > 1) label = label " (" seen[$3] ")"
        if ($2 == cur) label = "● " label
        if (mode == "show") print label
        else if (label == want) { print $1; exit }
      }'

    # Override tofi's fullscreen launcher geometry into a centered card sized to the
    # sink count, with a legible font (stylix's size is tuned for the fullscreen drun
    # launcher and reads tiny in a small card). Colors come from tofi.nix.
    n=$(printf '%s\n' "$sinks" | ${gawk} 'END { print NR }')
    height=$((160 + n * 56))

    label=$(printf '%s\n' "$sinks" \
      | ${gawk} -F '\t' -v cur="$current" -v mode=show "$mklabel" \
      | ${tofiBin} \
          --prompt-text "Output: " \
          --anchor center \
          --width 760 --height "$height" \
          --font-size 26 \
          --padding-top 36 --padding-bottom 36 \
          --padding-left 44 --padding-right 44 \
          --result-spacing 18 --num-results "$n" \
          --border-width 2 --corner-radius 16) || exit 0
    [ -n "$label" ] || exit 0

    id=$(printf '%s\n' "$sinks" \
      | ${gawk} -F '\t' -v cur="$current" -v mode=resolve -v want="$label" "$mklabel")
    [ -n "$id" ] || exit 1
    ${wpctl} set-default "$id"
  '';

  # --- Even split (Mod+G) ---------------------------------------------------
  # "Halve the screen between the focused window and its neighbour" — resolved
  # against the ORIENTATION of the output we're on. niri stacks windows only
  # *inside* a column, so the same intent needs two different layouts: on a
  # landscape output an even split is two half-width columns side by side, while
  # on a portrait one (the QD-OLED at transform 270 — see
  # homes/tempest/monitors.nix) it is ONE full-width column holding both windows,
  # halved top and bottom. Splitting horizontally on a 1440x2560 panel is what we
  # do NOT want: two 720-wide slivers.
  #
  # The vertical halving resets each window's height to *automatic* rather than
  # pinning 50%: niri divides a column's leftover space equally among auto-height
  # windows, so "auto everywhere" already IS the even split, and it stays right
  # for a column that ended up holding three.
  #
  # Each branch also undoes the other's shape, so the binding still does what it
  # says after the output is rotated: in portrait it consumes the neighbouring
  # column into the focused one, in landscape it expels a stacked window back out
  # into its own column.
  #
  # A floating window has no place in the scrolling layout, so there is nothing to
  # split against and we no-op.
  evenSplit = pkgs.writeShellScript "niri-even-split" ''
    set -u

    # Portrait = the output is taller than it is wide, which is exactly what a 90°
    # or −90° `transform` does to a landscape panel (1440x2560 on the rotated
    # QD-OLED). Deliberately NOT read off `.logical.transform`: its JSON spelling
    # is not one scheme — an unrotated output reports "Normal" while a rotated one
    # reports "270" — so matching names is a trap, whereas the geometry is the
    # thing we actually care about (and it does the right thing for a
    # natively-portrait panel too).
    portrait=$(${niri} msg --json focused-output \
      | ${jq} -r 'if (.logical.height // 0) > (.logical.width // 0) then 1 else 0 end')

    # Layout facts for the focused window in one query: how many windows share
    # its column, and how many sit in columns to its right / to its left. The
    # right/left counts double as "is there a column that way at all".
    facts=$(${niri} msg --json windows | ${jq} -r '
      ([.[] | select(.is_focused)] | first) as $f
      | if $f == null or $f.layout.pos_in_scrolling_layout == null then empty
        else
          ($f.layout.pos_in_scrolling_layout[0]) as $col
          | [ .[]
              | select(.workspace_id == $f.workspace_id)
              | .layout.pos_in_scrolling_layout // empty
              | .[0]
            ] as $cols
          | "\([$cols[] | select(. == $col)] | length)"
            + " \([$cols[] | select(. > $col)] | length)"
            + " \([$cols[] | select(. < $col)] | length)"
        end
    ')
    [ -n "$facts" ] || exit 0
    # shellcheck disable=SC2086
    set -- $facts
    mine=$1
    right=$2
    left=$3

    if [ "$portrait" = 1 ]; then
      if [ "$mine" -lt 2 ]; then
        # Alone in my column: pull the neighbour in. `consume-window-into-column`
        # only ever eats rightwards, so with no column to the right we step left
        # and let that column consume US.
        if [ "$right" -gt 0 ]; then
          ${niri} msg action consume-window-into-column
        elif [ "$left" -gt 0 ]; then
          ${niri} msg action focus-column-left
          ${niri} msg action consume-window-into-column
        else
          exit 0 # sole window on the workspace — nothing to split with
        fi
      fi

      # The stack owns the full width of a portrait screen; each window in it
      # gets an equal share of the height.
      ${niri} msg action set-column-width "100%"
      ${niri} msg --json windows | ${jq} -r '
        ([.[] | select(.is_focused)] | first) as $f
        | if $f == null or $f.layout.pos_in_scrolling_layout == null then empty
          else
            ($f.layout.pos_in_scrolling_layout[0]) as $col
            | .[]
            | select(.workspace_id == $f.workspace_id)
            | select((.layout.pos_in_scrolling_layout // [-1])[0] == $col)
            | .id
          end
      ' | while read -r id; do
        ${niri} msg action reset-window-height --id "$id"
      done
      exit 0
    fi

    # Landscape. A stacked column has to come apart first: expelling puts the
    # focused window in a fresh column to the right of the rest, so the pair to
    # halve is known — no neighbour search needed.
    if [ "$mine" -gt 1 ]; then
      ${niri} msg action expel-window-from-column
      ${niri} msg action set-column-width "50%"
      ${niri} msg action focus-column-left
      ${niri} msg action set-column-width "50%"
      ${niri} msg action focus-column-right
      exit 0
    fi

    # Already one window per column: resize the focused column and its neighbour
    # (preferring the one to the right), then hand focus back.
    ${niri} msg action set-column-width "50%"
    if [ "$right" -gt 0 ]; then
      ${niri} msg action focus-column-right
      ${niri} msg action set-column-width "50%"
      ${niri} msg action focus-column-left
    elif [ "$left" -gt 0 ]; then
      ${niri} msg action focus-column-left
      ${niri} msg action set-column-width "50%"
      ${niri} msg action focus-column-right
    fi
  '';

  # mkScratchpad builds the two scripts that drive one app's scratchpad. `spawn`
  # is the shell command launched (backgrounded) when the window doesn't exist.
  #   init   — launch-if-dead, wait for the window, then make it a scratchpad
  #            *member* (which also parks/hides it). `scratchpad-show` only acts
  #            on members, so this must succeed for toggling to work. Wire into
  #            spawn-at-startup for an always-open app; otherwise it runs lazily
  #            as the toggle's launch path.
  #   toggle — summon onto / dismiss from the focused workspace. `scratchpad-show`
  #            self-toggles for a member, so the common path is one call. But
  #            nirius can't *query* membership, so we verify via niri afterwards:
  #            if the window didn't move it wasn't a member yet, so we establish
  #            membership (park it, or pull it here) — making the toggle
  #            self-heal an un-parked or freshly-respawned window.
  mkScratchpad = { name, appId, spawn }:
    let
      exists = ''${niri} msg --json windows | ${jq} -e 'any(.[]; .app_id == "${appId}")' >/dev/null'';
      workspaceOf = ''${niri} msg --json windows | ${jq} -r 'first(.[] | select(.app_id == "${appId}")) | .workspace_id // empty' '';
      init = pkgs.writeShellScript "${name}-scratchpad-init" ''
        set -u
        if ! ${exists}; then
          ${spawn} &
        fi
        # Wait up to ~60s for the window to map — a slow (e.g. firejail) cold
        # start was otherwise leaving it un-parked, so the toggle silently no-op'd.
        i=0
        while [ "$i" -lt 600 ]; do
          ${exists} && break
          ${sleep} 0.1
          i=$((i + 1))
        done
        # Make it a scratchpad member (also parks/hides it). Retry until niriusd
        # accepts the request — spawn-at-startup entries launch concurrently —
        # but break on first success: a second toggle would un-member it.
        i=0
        while [ "$i" -lt 100 ]; do
          ${nirius} scratchpad-toggle --app-id "${appId}" && break
          ${sleep} 0.1
          i=$((i + 1))
        done
      '';
      toggle = pkgs.writeShellScript "${name}-scratchpad-toggle" ''
        set -u
        ws=$(${workspaceOf})
        if [ -z "$ws" ]; then
          # Not running → launch, park, then show it here.
          ${init}
          ${nirius} scratchpad-show --app-id "${appId}"
          exit 0
        fi
        fws=$(${niri} msg --json workspaces | ${jq} -r 'first(.[] | select(.is_focused)) | .id')
        ${nirius} scratchpad-show --app-id "${appId}"
        ${sleep} 0.15
        now=$(${workspaceOf})
        if [ "$ws" = "$fws" ] && [ "$now" = "$fws" ]; then
          # Meant to hide but stayed put → not a member → park it.
          ${nirius} scratchpad-toggle --app-id "${appId}"
        elif [ "$ws" != "$fws" ] && [ "$now" != "$fws" ]; then
          # Meant to summon but stayed away → not a member → pull it here.
          ${nirius} move-to-current-workspace --app-id "${appId}"
        fi
      '';
    in
    { inherit init toggle; };

  # Telegram: always-open (parked at login), summoned with Mod+T.
  # `telegram-sandboxed` is the firejail wrapper from desktop/telegram-sandbox.nix,
  # on PATH via home.packages.
  telegramScratchpad = mkScratchpad {
    name = "telegram";
    appId = "org.telegram.desktop";
    spawn = "telegram-sandboxed";
  };

  # Floating terminal: spawned on first use, summoned with Mod+Shift+Return. The
  # distinct --class gives wezterm its own app-id so the window-rule and nirius
  # target only this instance, not every wezterm window.
  #
  # --always-new-process is what makes that class stick: a plain `wezterm start`
  # asks an already-running GUI instance to spawn the window for it (the
  # single-instance rendezvous socket in $XDG_RUNTIME_DIR/wezterm is named after
  # the wayland display *and* the class), and a window spawned that way carries
  # the serving instance's app-id, not ours. Forcing our own process keeps the
  # app-id ours regardless.
  terminalScratchpad = mkScratchpad {
    name = "terminal";
    appId = "scratchpad-terminal";
    spawn = "${pkgs.wezterm}/bin/wezterm start --always-new-process --class scratchpad-terminal";
  };
in
lib.mkIf config.rices.niri.enable {
  programs.niri = {
    # Not the compositor — the session comes from the system package. This is what
    # home-manager validates the generated KDL against, so it has to be the same
    # version that will actually load it (see the `niri` binding above).
    package = pkgs.niri-stable;
    settings = {
      environment = {
        CLUTTER_BACKEND = "wayland";
        GDK_BACKEND = "wayland,x11";
        MOZ_ENABLE_WAYLAND = "1";
        NIXOS_OZONE_WL = "1";
        QT_QPA_PLATFORM = "wayland";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        # Apps launched from niri (binds / tofi-drun) inherit this env, not the
        # systemd user env (spawn-at-startup only imports 4 vars). Set the Qt
        # platform theme here so Dolphin et al. pick up qt.nix's qtct config +
        # Noctalia's dynamic color file. "qt5ct" also loads the qt6ct plugin
        # (its plugin Keys are ["qt6ct","qt5ct"]). No QT_STYLE_OVERRIDE — style
        # is selected by qtct.conf (style=Fusion).
        QT_QPA_PLATFORMTHEME = "qt5ct";
        ELECTRON_OZONE_PLATFORM_HINT = "wayland";
        XDG_SESSION_TYPE = "wayland";
        XDG_CURRENT_DESKTOP = "niri";
        # Noctalia's lockscreen authenticates against this PAM service (read by
        # its LockContext). Default is "login", which assumes a privileged caller
        # — an unprivileged locker hits "pam_unix(login:account): setuid failed"
        # and can never unlock. Point it at a dedicated /etc/pam.d/noctalia
        # instead (defined in rices/niri/system.nix). niri exports this to the
        # processes it spawns, including the noctalia spawn-at-startup, so the
        # already-running shell that handles every lock path picks it up.
        NOCTALIA_PAM_SERVICE = "noctalia";
      };

      hotkey-overlay = {
        skip-at-startup = true;
      };

      xwayland-satellite.enable = true;

      gestures = {
        hot-corners.enable = false;
      };

      # Input configuration
      input = {
        focus-follows-mouse.enable = true;

        keyboard = {
          xkb = {
            layout = "us";
            variant = "intl";
          };
        };

        touchpad = {
          tap = true;
          natural-scroll = true;
          accel-speed = 0.3;
          scroll-factor = 0.8;
        };

        mouse = {
          natural-scroll = false;
          accel-speed = -0.4;
          scroll-factor = 0.8;
        };
      };

      layout = {
        background-color = "transparent";

        default-column-width.proportion = 1.0;

        shadow.enable = false;

        focus-ring.enable = false;

        border = {
          enable = true;
          width = 2;
          active.color = c.base03;
          inactive.color = c.base01;
        };

        # Gap windows away from the screen edges so they sit inside the floating
        # Noctalia bar's margin (noctalia-widgets.nix sets the bar's margins to
        # the same value, so window columns line up with the bar's edges).
        gaps = 8;
      };

      # Prefer no client-side decorations
      prefer-no-csd = true;

      # Animations (conditional on host)
      animations = {
        slowdown = 0.7;
      };

      # Spawn commands at startup
      spawn-at-startup = [
        {
          command = [
            "${pkgs.systemd}/bin/systemctl"
            "--user"
            "import-environment"
            "WAYLAND_DISPLAY"
            "XDG_CURRENT_DESKTOP"
            "DBUS_SESSION_BUS_ADDRESS"
            "XAUTHORITY"
          ];
        }
        # NNN stack: the Noctalia shell (bar + notifications + launcher) is NOT
        # spawned here anymore. It runs as a supervised systemd user service
        # (programs.noctalia.systemd.enable, in rices/niri/noctalia.nix) with
        # Restart=on-failure bound to graphical-session.target, so a segfault in
        # the v5 dev build self-heals instead of leaving a dead desktop. Spawning
        # it here too would double-launch a singleton shell.
        # Scratchpads: the nirius daemon, then launch Telegram and park it hidden
        # in the scratchpad. Mod+T summons it. The terminal scratchpad
        # (Mod+Shift+Return) is spawned lazily on first use, so it isn't here.
        # See the let block above.
        { command = [ "${pkgs.nirius}/bin/niriusd" ]; }
        { command = [ "${telegramScratchpad.init}" ]; }
      ];

      # Keybindings
      binds = with pkgs; {
        # Terminal and launcher. Bare `wezterm` defaults to the `start`
        # subcommand, which hands the request to a running wezterm GUI instance
        # of the same class when there is one — so extra windows are cheap
        # (kitty was a fresh process per press). The scratchpad below
        # deliberately opts out of that; see the let block.
        "Mod+Return".action.spawn = [
          "${pkgs.wezterm}/bin/wezterm"
        ];
        # Floating terminal scratchpad: summon/dismiss a near-fullscreen floating
        # wezterm (own app-id "scratchpad-terminal"); see the let block above.
        "Mod+Shift+Return".action.spawn = [ "${terminalScratchpad.toggle}" ];
        # Disabled for now (Emacs server is off — see desktop/emacs/default.nix).
        # This key used to open a new Emacs frame on the running daemon. Bare
        # "emacsclient" so niri picks up the home-manager-installed myEmacs from
        # PATH rather than pulling a second emacs build into the niri closure.
        # Pass `-d $WAYLAND_DISPLAY` (e.g. "wayland-1") so the pgtk daemon
        # asks GDK for a Wayland display rather than inheriting niri's
        # xwayland DISPLAY=:0 and opening an X11 frame ("pure-GTK under X"
        # warning). Wayland frame shows up in `niri msg windows` with the
        # lowercase app id "emacs"; the X11 fallback is "Emacs".
        # "Mod+Shift+Return".action.spawn = [
        #   "sh"
        #   "-c"
        #   ''exec emacsclient -c -d "$WAYLAND_DISPLAY"''
        # ];
        # Same key as before; now drives Noctalia's launcher instead of tofi.
        # v5 IPC: `noctalia msg <command>` replaced `noctalia-shell ipc call …`;
        # the launcher panel is toggled via the generic panel-toggle handler.
        "Mod+Space".action.spawn = [
          "noctalia"
          "msg"
          "panel-toggle"
          "launcher"
        ];

        "Mod+B".action.spawn = [ "${pkgs.blueman}/bin/blueman-manager" ];
        "Mod+P".action.spawn = [ "${pkgs.pavucontrol}/bin/pavucontrol" ];
        # Pick the default output device by name (EasyEffects follows it).
        "Mod+O".action.spawn = [ "${audioOutputSwitcher}" ];
        "Mod+N".action.spawn = [ "${pkgs.kdePackages.dolphin}/bin/dolphin" ];
        "Mod+L".action.spawn = [ "${pkgs.systemd}/bin/loginctl" "lock-session" ];

        # Telegram scratchpad: summon/dismiss on the focused workspace.
        "Mod+T".action.spawn = [ "${telegramScratchpad.toggle}" ];
        # Send the focused window into / pull it out of the scratchpad.
        "Mod+Shift+T".action.spawn = [ "${nirius}" "scratchpad-toggle" ];

        # Window management
        "Mod+Q".action.close-window = { };
        "Mod+F".action.fullscreen-window = { };
        "Mod+M".action.maximize-column = { };

        # Even 50/50 split of the focused window and its neighbour, along
        # whichever axis suits the output's orientation — two half-width columns
        # in landscape, one full-width column halved top/bottom in portrait.
        "Mod+G".action.spawn = [ "${evenSplit}" ];

        # Focus movement
        "Mod+Left".action.focus-column-left = { };
        "Mod+Right".action.focus-column-right = { };
        "Mod+Up".action.focus-window-up = { };
        "Mod+Down".action.focus-window-down = { };

        # Move windows
        "Mod+Shift+Left".action.move-column-left = { };
        "Mod+Shift+Right".action.move-column-right = { };
        "Mod+Shift+Up".action.move-window-up = { };
        "Mod+Shift+Down".action.move-window-down = { };

        # Browser
        "Mod+Shift+B".action.spawn = [ "${inputs.zen-browser.packages.x86_64-linux.beta}/bin/zen-beta" ];

        # Screenshots (using niri's built-in UI)
        "Mod+Shift+S".action.screenshot = { };
        "Mod+Shift+D".action.screenshot-screen = { };

        # Workspaces 1-10
        "Mod+1".action.focus-workspace = 1;
        "Mod+2".action.focus-workspace = 2;
        "Mod+3".action.focus-workspace = 3;
        "Mod+4".action.focus-workspace = 4;
        "Mod+5".action.focus-workspace = 5;
        "Mod+6".action.focus-workspace = 6;
        "Mod+7".action.focus-workspace = 7;
        "Mod+8".action.focus-workspace = 8;
        "Mod+9".action.focus-workspace = 9;
        "Mod+0".action.focus-workspace = 10;

        # Move to workspaces 1-10
        "Mod+Shift+1".action.move-window-to-workspace = 1;
        "Mod+Shift+2".action.move-window-to-workspace = 2;
        "Mod+Shift+3".action.move-window-to-workspace = 3;
        "Mod+Shift+4".action.move-window-to-workspace = 4;
        "Mod+Shift+5".action.move-window-to-workspace = 5;
        "Mod+Shift+6".action.move-window-to-workspace = 6;
        "Mod+Shift+7".action.move-window-to-workspace = 7;
        "Mod+Shift+8".action.move-window-to-workspace = 8;
        "Mod+Shift+9".action.move-window-to-workspace = 9;
        "Mod+Shift+0".action.move-window-to-workspace = 10;

        # Media keys
        "XF86AudioRaiseVolume".action.spawn = [
          "${pamixer}/bin/pamixer"
          "-i"
          "5"
        ];
        "XF86AudioLowerVolume".action.spawn = [
          "${pamixer}/bin/pamixer"
          "-d"
          "5"
        ];
        "XF86AudioMute".action.spawn = [
          "${pamixer}/bin/pamixer"
          "--toggle-mute"
        ];
        # Brightness keys route through brightnessAdjust: backlight when the
        # laptop panel is active, ddcutil/DDC-CI when clamshell (see let block).
        "XF86MonBrightnessUp".action.spawn = [ "${brightnessAdjust}" "up" ];
        "XF86MonBrightnessDown".action.spawn = [ "${brightnessAdjust}" "down" ];

        # Media control
        "XF86AudioPlay".action.spawn = [
          "${playerctl}/bin/playerctl"
          "play-pause"
        ];
        "XF86AudioNext".action.spawn = [
          "${playerctl}/bin/playerctl"
          "next"
        ];
        "XF86AudioPrev".action.spawn = [
          "${playerctl}/bin/playerctl"
          "previous"
        ];

        # Toggle floating (niri alternative - use center-column)
        "Mod+Shift+Space".action.center-column = { };

        "Mod+E".action.toggle-overview = { };

        # Quit niri
        "Mod+Shift+E".action.quit.skip-confirmation = true;
      };
      window-rules = windowRules;
      layer-rules = [
        # Noctalia's wallpaper surface (background layer, ignores exclusive
        # zones) — reparent it into niri's backdrop so it shows behind
        # gapped/transparent windows and in the overview. v5 uses a single fixed
        # layer-shell namespace "noctalia-wallpaper" (v4 carried a per-output
        # suffix); prefix match keeps it forward-compatible.
        {
          matches = [{ namespace = "^noctalia-wallpaper"; }];
          place-within-backdrop = true;
        }
      ];
    };
  };
}
