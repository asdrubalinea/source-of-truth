{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: let
  windowRules = import ./window-rules.nix c;
  playClipboard = import ../../play-clipboard.nix {inherit pkgs;};
  sitrepHud = import ../../sitrep-hud.nix {inherit pkgs;};
  c = config.lib.stylix.colors.withHashtag;

  # --- Scratchpads (nirius-backed) -----------------------------------------
  # niri has no truly hidden workspace, so the "scratchpad" is the bottom-most
  # one; niriusd tracks membership and nirius flips windows in/out. Geometry
  # lives in window-rules.nix, per app-id. See ADR 0006.
  #
  # The `niri` CLI and the running compositor MUST be the same package. On a
  # mismatch `niri msg` prints a version complaint on stdout *instead of* the
  # JSON, so every `--json` consumer here silently gets a jq parse error. The
  # compositor is the system one (greetd runs niri-session from
  # /run/current-system/sw), so changing it means changing
  # `programs.niri.package` and every pkgs.niri-unstable in this rice together
  # (niri.nix, marquee.nix, pip-follow.nix, swayidle.nix).
  niri = "${pkgs.niri-unstable}/bin/niri";
  jq = "${pkgs.jq}/bin/jq";
  nirius = "${pkgs.nirius}/bin/nirius";
  sleep = "${pkgs.coreutils}/bin/sleep";

  # --- Brightness (Mod brightness keys) ------------------------------------
  # One control, two backends: brightnessctl on the internal panel's backlight
  # while it is an active output, DDC/CI (VCP 0x10) otherwise, since a
  # clamshell-docked external has no backlight to write. `internalOutput`
  # (./default.nix) is the only host fact this file reads. ddcutil needs
  # hardware.i2c.enable and only succeeds on externals that expose DDC/CI. See
  # ADR 0009.
  brightnessAdjust = pkgs.writeShellScript "brightness-adjust" ''
    set -u
    dir="''${1:-up}"
    step=5
    if ${niri} msg --json outputs | ${jq} -e '(."${config.rices.ember.internalOutput}".logical // null) != null' >/dev/null 2>&1; then
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
  # Name-based, so a pick survives reboots: PipeWire node *ids* are reassigned
  # but wpctl persists the choice by stable node name. EasyEffects' virtual
  # "easyeffects_sink" is hidden (picking it is meaningless — apps already feed
  # it), and setting a real device is the trigger EasyEffects watches to route
  # its pipeline and swap the speaker preset. The configured default is marked
  # ● so the menu reflects present state. Sinks with no node.description are
  # skipped, and duplicate descriptions get a "(n)" suffix, so each row maps to
  # exactly one id. No-ops when the host has no sinks.
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

    # Run twice over the same $sinks so both passes build identical rows:
    # mode=show prints the menu, mode=resolve prints the selected row's id.
    # Non-current rows carry no leading whitespace, so a picker that trims the
    # returned line can't break the round-trip.
    mklabel='
      { seen[$3]++
        label = $3
        if (seen[$3] > 1) label = label " (" seen[$3] ")"
        if ($2 == cur) label = "● " label
        if (mode == "show") print label
        else if (label == want) { print $1; exit }
      }'

    # Geometry, font and colours come from ./tofi.nix — do not add --width,
    # --height or --anchor here. A sized tofi window is unreadable on tempest's
    # portrait panel; that file says why, with numbers.
    label=$(printf '%s\n' "$sinks" \
      | ${gawk} -F '\t' -v cur="$current" -v mode=show "$mklabel" \
      | ${tofiBin} --prompt-text "Output: ") || exit 0
    [ -n "$label" ] || exit 0

    id=$(printf '%s\n' "$sinks" \
      | ${gawk} -F '\t' -v cur="$current" -v mode=resolve -v want="$label" "$mklabel")
    [ -n "$id" ] || exit 1
    ${wpctl} set-default "$id"
  '';

  # --- Even split (Mod+G) ---------------------------------------------------
  # "Halve the screen between the focused window and its neighbour", resolved
  # against the output's ORIENTATION. niri stacks windows only inside a column,
  # so the intent needs two layouts: landscape gets two half-width columns,
  # portrait gets ONE full-width column halved top and bottom. Splitting
  # horizontally on a 1440x2560 panel would give two 720-wide slivers.
  #
  # The vertical halving resets heights to *automatic* rather than pinning 50%:
  # niri divides leftover space equally among auto-height windows, so "auto
  # everywhere" already IS the even split — and stays right for three windows.
  #
  # Each branch undoes the other's shape, so the binding still means what it says
  # after a rotation. A floating window has nothing to split against: no-op.
  evenSplit = pkgs.writeShellScript "niri-even-split" ''
    set -u

    # Portrait = taller than wide. Deliberately NOT read off
    # `.logical.transform`, whose JSON spelling is not one scheme (unrotated
    # reports "Normal", rotated reports "270"), so name-matching is a trap.
    # Geometry is the thing we care about, and it's also right for a natively
    # portrait panel.
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

  # The two scripts driving one app's scratchpad. `spawn` is launched
  # backgrounded when the window doesn't exist.
  #   init   — launch-if-dead, wait for the window, make it a scratchpad
  #            *member* (which parks it). `scratchpad-show` only acts on members,
  #            so this must succeed for toggling to work.
  #   toggle — `scratchpad-show` self-toggles for a member, so the common path is
  #            one call. nirius can't *query* membership, so we check via niri
  #            afterwards: if the window didn't move it wasn't a member, and we
  #            establish it — which self-heals a freshly-respawned window.
  mkScratchpad = {
    name,
    appId,
    spawn,
  }: let
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
  in {inherit init toggle;};

  # Telegram: always-open (parked at login), summoned with Mod+T.
  # `telegram-sandboxed` is the firejail wrapper from desktop/telegram-sandbox.nix,
  # on PATH via home.packages.
  telegramScratchpad = mkScratchpad {
    name = "telegram";
    appId = "org.telegram.desktop";
    spawn = "telegram-sandboxed";
  };

  # Floating terminal, spawned on first use. The distinct --class gives it its
  # own app-id so the window-rule and nirius target only this instance.
  # --always-new-process is what makes that class stick: a plain `wezterm start`
  # asks a running instance to spawn the window, and it comes back carrying that
  # instance's app-id, not ours.
  terminalScratchpad = mkScratchpad {
    name = "terminal";
    appId = "scratchpad-terminal";
    spawn = "${pkgs.wezterm}/bin/wezterm start --always-new-process --class scratchpad-terminal";
  };
in
  lib.mkIf config.rices.ember.niri.enable {
    programs.niri = {
      # Not the compositor — the session comes from the system package. This is what
      # home-manager validates the generated KDL against, so it has to be the same
      # version that will actually load it (see the `niri` binding above).
      package = pkgs.niri-unstable;
      settings = {
        environment = {
          CLUTTER_BACKEND = "wayland";
          GDK_BACKEND = "wayland,x11";
          MOZ_ENABLE_WAYLAND = "1";
          NIXOS_OZONE_WL = "1";
          QT_QPA_PLATFORM = "wayland";
          QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
          # Apps launched from niri inherit this env, not the systemd user env
          # (import-environment only carries 4 vars). "qt5ct" also loads the
          # qt6ct plugin, so Dolphin et al. pick up qt.nix's qtct config. No
          # QT_STYLE_OVERRIDE — style is selected by qtct.conf.
          QT_QPA_PLATFORMTHEME = "qt5ct";
          ELECTRON_OZONE_PLATFORM_HINT = "wayland";
          XDG_SESSION_TYPE = "wayland";
          XDG_CURRENT_DESKTOP = "niri";
          # Noctalia's lockscreen defaults to PAM "login", which assumes a
          # privileged caller — an unprivileged locker hits "setuid failed" and
          # can never unlock. Point it at the dedicated service defined in
          # rices/ember/system.nix.
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
            # Same palette entries, alpha-dimmed (ff = undimmed): on OLED the
            # borders blend against near-black, so alpha darkens without
            # shifting hue.
            #
            # TRIED AND REJECTED: base09 at ff for the active border. A bright
            # ring reads as an alert, not as focus, and it is exactly the
            # always-lit static content ADR 0009 exists to avoid. Don't redo it.
            active.color = c.base03 + "73"; # 45%
            inactive.color = c.base01 + "26"; # 15%
          };

          # Inner gaps only: `gaps` applies both between windows and around the
          # screen edges, and matching negative struts cancel the outer half —
          # the documented niri idiom. A lone window then runs edge to edge while
          # two or more still get 2*gaps between columns. niri has no
          # smart-gaps (rules can't match on window count), so this is as close
          # as it gets without an event-stream daemon.
          gaps = 8;

          # -8 on all four. `top` used to be 0 to keep a square window corner
          # from clashing with the floating bar's 12px curve — but the bar
          # reserves no space, so that 0 bought nothing but an 8px strip of
          # wallpaper across every tiled window. The bar is flush and square now
          # (rices/ember/noctalia-widgets.nix), so there is no curve to dodge.
          struts = {
            left = -8;
            right = -8;
            top = -8;
            bottom = -8;
          };
        };

        # Prefer no client-side decorations
        prefer-no-csd = true;

        # Compositor-drawn cursor, DERIVED from stylix.cursor (which themes the
        # client-drawn ones); the mango layer reads the same root. niri's own
        # default is "default", so without this the pointer would change
        # appearance as it moved between niri's surfaces and an app's.
        cursor = {
          theme = config.stylix.cursor.name;
          size = config.stylix.cursor.size;
        };

        # Animations. Force-disabled in the VM only (hosts/tempest/vm.nix) — every
        # animated frame there goes through the emulated virgl path.
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
          # Noctalia is deliberately NOT spawned here — it runs as a supervised
          # user service (rices/ember/noctalia.nix), and spawning it here too
          # would double-launch a singleton shell.
          #
          # Scratchpads: the nirius daemon, then Telegram parked hidden (Mod+T
          # summons it). The terminal scratchpad is spawned lazily on first use,
          # so it isn't here. See the let block above.
          {command = ["${pkgs.nirius}/bin/niriusd"];}
          {command = ["${telegramScratchpad.init}"];}
        ];

        # Keybindings
        binds = with pkgs; {
          # Bare `wezterm` defaults to `start`, which hands the request to a
          # running instance of the same class, so extra windows are cheap
          # (kitty was a fresh process per press). The scratchpad above
          # deliberately opts out of that.
          "Mod+Return".action.spawn = [
            "${pkgs.wezterm}/bin/wezterm"
          ];
          # Floating terminal scratchpad: summon/dismiss a near-fullscreen floating
          # wezterm (own app-id "scratchpad-terminal"); see the let block above.
          "Mod+Shift+Return".action.spawn = ["${terminalScratchpad.toggle}"];
          # Same key as before; now drives Noctalia's launcher instead of tofi.
          # v5 IPC: `noctalia msg <command>` replaced `noctalia-shell ipc call …`;
          # the launcher panel is toggled via the generic panel-toggle handler.
          "Mod+Space".action.spawn = [
            "noctalia"
            "msg"
            "panel-toggle"
            "launcher"
          ];

          "Mod+B".action.spawn = ["${pkgs.blueman}/bin/blueman-manager"];
          "Mod+P".action.spawn = ["${pkgs.pavucontrol}/bin/pavucontrol"];
          # Pick the default output device by name (EasyEffects follows it).
          "Mod+O".action.spawn = ["${audioOutputSwitcher}"];
          "Mod+N".action.spawn = ["${pkgs.kdePackages.dolphin}/bin/dolphin"];
          "Mod+L".action.spawn = ["${pkgs.systemd}/bin/loginctl" "lock-session"];
          # Instrument panel: a floating, transient `sitrep`. See
          # ../../sitrep-hud.nix for why this is a keybind and not a bar widget.
          "Mod+I".action.spawn = ["${sitrepHud}"];

          # Telegram scratchpad: summon/dismiss on the focused workspace.
          "Mod+T".action.spawn = ["${telegramScratchpad.toggle}"];
          # Send the focused window into / pull it out of the scratchpad.
          "Mod+Shift+T".action.spawn = ["${nirius}" "scratchpad-toggle"];

          # Window management
          "Mod+Q".action.close-window = {};
          "Mod+F".action.fullscreen-window = {};
          "Mod+M".action.maximize-column = {};

          # Even 50/50 split of the focused window and its neighbour, along
          # whichever axis suits the output's orientation — two half-width columns
          # in landscape, one full-width column halved top/bottom in portrait.
          "Mod+G".action.spawn = ["${evenSplit}"];

          # Focus movement
          "Mod+Left".action.focus-column-left = {};
          "Mod+Right".action.focus-column-right = {};
          "Mod+Up".action.focus-window-up = {};
          "Mod+Down".action.focus-window-down = {};

          # Move windows
          "Mod+Shift+Left".action.move-column-left = {};
          "Mod+Shift+Right".action.move-column-right = {};
          "Mod+Shift+Up".action.move-window-up = {};
          "Mod+Shift+Down".action.move-window-down = {};

          # Browser
          "Mod+Shift+B".action.spawn = ["${inputs.zen-browser.packages.x86_64-linux.beta}/bin/zen-beta"];

          # Copy a video URL, play it in mpv instead of the browser's decoder.
          "Mod+Y".action.spawn = ["${playClipboard}"];

          # Screenshots (using niri's built-in UI)
          "Mod+Shift+S".action.screenshot = {};
          "Mod+Shift+D".action.screenshot-screen = {};

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
          "XF86MonBrightnessUp".action.spawn = ["${brightnessAdjust}" "up"];
          "XF86MonBrightnessDown".action.spawn = ["${brightnessAdjust}" "down"];

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
          "Mod+Shift+Space".action.center-column = {};

          "Mod+E".action.toggle-overview = {};

          # Quit niri
          "Mod+Shift+E".action.quit.skip-confirmation = true;
        };
        window-rules = windowRules;
        layer-rules = [
          # Reparent Noctalia's wallpaper surface into niri's backdrop so it
          # shows behind gapped/transparent windows and in the overview. Prefix
          # match, since v4 carried a per-output namespace suffix and v5 doesn't.
          {
            matches = [{namespace = "^noctalia-wallpaper";}];
            place-within-backdrop = true;
          }
        ];
      };
    };
  }
