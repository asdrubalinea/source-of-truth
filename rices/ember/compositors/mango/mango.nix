{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: let
  cfg = config.rices.ember;

  # Stylix's palette WITHOUT the leading '#': mango takes colours as 0xRRGGBBAA,
  # so the hex pairs are concatenated by hand below. (The niri layer uses
  # `.withHashtag` for the same values — same scheme, different literal syntax.)
  c = config.lib.stylix.colors;
  colour = alpha: base: "0x${base}${alpha}";

  windowRules = import ./window-rules.nix;
  playClipboard = import ../../play-clipboard.nix {inherit pkgs;};
  sitrepHud = import ../../sitrep-hud.nix {inherit pkgs;};

  # mango has no built-in `screenshot` action, so both binds go through
  # grim/slurp. A script rather than an inline command because mango's bind
  # parser splits on commas, which a save-then-copy pipeline would not survive.
  screenshot = pkgs.writeShellScript "ember-screenshot" ''
    set -euo pipefail
    dir="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
    ${pkgs.coreutils}/bin/mkdir -p "$dir"
    file="$dir/$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S).png"
    case "''${1:-region}" in
      region)
        # Freeze first: slurp waits for the user, so without this grim captures
        # whatever the screen drifted to while the region was drawn — a closed
        # menu, an expired tooltip. wayfreeze overlays a screencopy, slurp maps
        # above it, grim re-captures the same static pixels. Only `region` needs
        # it; `screen` grabs at keypress.
        ${pkgs.wayfreeze}/bin/wayfreeze &
        freeze=$!
        trap 'kill "$freeze" 2>/dev/null || true' EXIT
        # ponytail: fixed wait for the overlay to map. wayfreeze signals ready
        # only via --after-freeze-cmd, which would mean nesting the whole
        # slurp/grim pipeline in a quoted string. Raise if it ever races.
        sleep 0.15
        ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$file"
        ;;
      screen) ${pkgs.grim}/bin/grim "$file" ;;
      *) exit 2 ;;
    esac
    ${pkgs.wl-clipboard}/bin/wl-copy < "$file"
  '';

  wezterm = "${pkgs.wezterm}/bin/wezterm";

  # --- Even split (Mod+G) ---------------------------------------------------
  # The niri layer's evenSplit ported to mango's scroller: same intent, same
  # orientation-awareness, different vocabulary. See ../niri/niri.nix for the
  # reasoning; only the mango-specific parts are noted here.
  #
  # `scroller_stack` is consume *and* expel in one action — it pulls the
  # neighbour into the focused window's stack, or moves an already-stacked
  # window out into its own column — so each branch undoes the other's shape.
  # Heights need no setting: mango normalises a stack node's proportion to an
  # equal share whenever it is outside (0,1), so a fresh stack is already even.
  # Portrait is read off logical geometry, not a transform name, for the reason
  # the niri layer spells out. Floating windows have nothing to split against.
  evenSplit = pkgs.writeShellScript "mango-even-split" ''
    set -u
    mmsg=${pkgs.mango}/bin/mmsg
    jq=${pkgs.jq}/bin/jq

    # Sets: portrait, id (focused), mine (windows sharing its column), right/left
    # (the id of the nearest column that way, or 0). Columns are keyed on x —
    # every window in one shares it.
    query() {
      mon=$("$mmsg" get all-monitors | "$jq" -r '
        [.monitors[] | select(.active)] | first
        | if . == null then empty
          else "\(.name) \(if .height > .width then 1 else 0 end)" end')
      [ -n "$mon" ] || return 1
      # shellcheck disable=SC2086
      set -- $mon
      name=$1
      portrait=$2

      facts=$("$mmsg" get all-clients | "$jq" -r --arg m "$name" '
        [.clients[] | select(.monitor == $m and .is_visible and (.is_floating | not))] as $t
        | ([$t[] | select(.is_focused)] | first) as $f
        | if $f == null then empty
          else
            "\($f.id)"
            + " \([$t[] | select(.x == $f.x)] | length)"
            + " \(([$t[] | select(.x > $f.x)] | sort_by(.x) | first | .id) // 0)"
            + " \(([$t[] | select(.x < $f.x)] | sort_by(-.x) | first | .id) // 0)"
          end')
      [ -n "$facts" ] || return 1
      # shellcheck disable=SC2086
      set -- $facts
      id=$1
      mine=$2
      right=$3
      left=$4
    }

    query || exit 0

    if [ "$portrait" = 1 ]; then
      if [ "$mine" -lt 2 ]; then
        if [ "$right" != 0 ]; then
          "$mmsg" dispatch scroller_stack,right
        elif [ "$left" != 0 ]; then
          "$mmsg" dispatch scroller_stack,left
        else
          exit 0 # sole window on the tag — nothing to split with
        fi
      fi
      "$mmsg" dispatch set_proportion,1.0
      exit 0
    fi

    # Landscape. A stacked window comes out into its own column first, which
    # changes the layout under us, so re-read it.
    if [ "$mine" -gt 1 ]; then
      "$mmsg" dispatch scroller_stack,right
      query || exit 0
    fi

    if [ "$right" != 0 ]; then
      neighbour=$right
    elif [ "$left" != 0 ]; then
      neighbour=$left
    else
      exit 0
    fi
    "$mmsg" dispatch set_proportion,0.5 client,"$id"
    "$mmsg" dispatch set_proportion,0.5 client,"$neighbour"
  '';

  # mango is tag-based (a dwl inheritance): unlike niri's dynamic per-output
  # workspaces the ten tags always exist, a window can be on several at once,
  # and an empty tag doesn't disappear. Ten, so Mod+1..0 matches niri.
  tagCount = 10;
  tagRules = map (i: "id:${toString i},layout_name:scroller") (lib.range 1 tagCount);
in {
  config = lib.mkIf (cfg.enable && cfg.mango.enable) {
    # mango re-reads config.conf only when told to, and the file is a store
    # symlink activation swaps rather than edits in place — so poke it once the
    # new generation is linked and `nh home switch` alone applies a config edit.
    # `|| true` because this also runs from the niri session, from a TTY, and on
    # a first activation with no compositor, where mmsg must not fail the switch.
    home.activation.reloadMango = lib.hm.dag.entryAfter ["linkGeneration"] ''
      run ${pkgs.mango}/bin/mmsg dispatch reload_config > /dev/null 2>&1 || true
    '';

    wayland.windowManager.mango = {
      enable = true;

      # Pinned to the same derivation the system session runs and swayidle calls
      # `mmsg` from. mango's IPC socket is versionless, so a mismatch fails at
      # runtime rather than at build — the bug class the niri layer describes.
      package = pkgs.mango;

      # MUST be non-empty. The HM module writes autostart.sh — and the
      # `exec-once` that runs it — only when this is set, and that script is
      # where dbus-update-activation-environment and `systemctl --user start
      # mango-session.target` live. Empty means graphical-session.target never
      # starts and the whole rest of the rice silently never launches.
      #
      # Nothing else belongs here: Noctalia is a supervised user service, and
      # the scratchpads launch lazily on first toggle rather than being
      # spawned-and-hidden the way the niri layer has to do it.
      autostart_sh = ''
        # (systemd/D-Bus activation is prepended by the module itself)
      '';

      settings = {
        # --- Session environment ------------------------------------------
        # Mirrors the niri layer's block. XDG_CURRENT_DESKTOP is the one value
        # that must differ: portals pick a backend by it, and Noctalia
        # identifies the compositor by it when the signature isn't visible.
        env = [
          "CLUTTER_BACKEND,wayland"
          "GDK_BACKEND,wayland,x11"
          "MOZ_ENABLE_WAYLAND,1"
          "NIXOS_OZONE_WL,1"
          "QT_QPA_PLATFORM,wayland"
          "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
          "QT_QPA_PLATFORMTHEME,qt5ct"
          "ELECTRON_OZONE_PLATFORM_HINT,wayland"
          "XDG_SESSION_TYPE,wayland"
          "XDG_CURRENT_DESKTOP,mango"
          # Not `login`, which refuses an unprivileged caller. Defined in
          # ../../system.nix; set per session, hence in both layers.
          "NOCTALIA_PAM_SERVICE,noctalia"
        ];

        # --- Tags and layout ----------------------------------------------
        tag_num = tagCount;
        tagrule = tagRules;

        # Tuned to match niri's `default-column-width.proportion = 1.0`: one
        # full-width column at a time. structs is the sliver mango reserves to
        # reveal the neighbour; niri reveals nothing at 1.0, so it goes to 0.
        scroller_default_proportion = 1.0;
        scroller_structs = 0;
        scroller_proportion_preset = "0.5,0.8,1.0";

        # --- Dimensions ----------------------------------------------------
        # 8px between windows, none at the screen edge. mango splits inner and
        # outer directly, so it needs no negative-strut trick as niri does.
        borderpx = 2;
        gappih = 8;
        gappiv = 8;
        gappoh = 0;
        gappov = 0;
        # Square, derived from the bar's edge treatment exactly as niri's
        # geometry-corner-radius is — see "bar" in CONTEXT.md.
        border_radius = 0;
        smartgaps = 0;

        # --- Effects -------------------------------------------------------
        # scenefx can do more than niri (blur, per-window opacity), deliberately
        # unused: the brief was "the same desktop, different engine".
        blur = 0;
        shadows = 1;
        shadow_only_floating = 1;
        focused_opacity = 1.0;
        unfocused_opacity = 1.0;

        # --- Colours -------------------------------------------------------
        # Derived from the stylix scheme, same two values the niri layer uses:
        # active base03 at 45%, inactive base01 at 15%. Noctalia ships its own
        # mango colour template — leave it OFF, it would write into
        # ~/.config/mango, which HM owns as a read-only store symlink.
        #
        # urgentcolor through splitcolor are ALSO border colours (mango swaps the
        # border while a window is in that state), so they take the same alpha as
        # the focused border. At ff they were the one thing glowing at full
        # brightness against near-black. rootcolor/shadowscolor aren't borders
        # and stay opaque. (See the TRIED AND REJECTED note in ../niri/niri.nix.)
        focuscolor = colour "73" c.base03;
        bordercolor = colour "26" c.base01;
        rootcolor = colour "ff" c.base00;
        urgentcolor = colour "73" c.base08;
        scratchpadcolor = colour "73" c.base0E;
        globalcolor = colour "73" c.base0D;
        overlaycolor = colour "73" c.base0C;
        maximizescreencolor = colour "73" c.base0B;
        shadowscolor = colour "ff" c.base00;
        splitcolor = colour "73" c.base0A;
        dropcolor = colour "80" c.base0A;

        # --- Animations ----------------------------------------------------
        # niri runs its own animations at `slowdown = 0.7`; these are mango's
        # defaults times roughly that, so window motion feels the same speed.
        animations = 1;
        animation_duration_open = 280;
        animation_duration_close = 210;
        animation_duration_move = 350;
        animation_duration_tag = 210;

        # --- Focus and pointer ---------------------------------------------
        sloppyfocus = 1; # niri: input.focus-follows-mouse
        warpcursor = 0; # niri does not warp the pointer on keyboard focus
        enable_hotarea = 0; # niri: gestures.hot-corners.enable = false

        # --- Cursor ----------------------------------------------------------
        # DERIVED from stylix.cursor, the root both layers follow: it has to
        # match or the pointer changes appearance depending on which surface it
        # is over. Unset, wlroots falls back to the X11 core cursor.
        cursor_theme = config.stylix.cursor.name;
        cursor_size = config.stylix.cursor.size;

        # --- Input ----------------------------------------------------------
        xkb_rules_layout = "us";
        xkb_rules_variant = "intl";
        tap_to_click = 1;
        trackpad_natural_scrolling = 1;
        trackpad_accel_speed = 0.3;
        trackpad_scroll_factor = 0.8;
        mouse_natural_scrolling = 0;
        mouse_accel_speed = -0.4;

        windowrule = windowRules;

        # --- Keybindings ----------------------------------------------------
        # Same keys as the niri layer wherever the action exists on both sides.
        # docs/mango-vs-niri.md has the full mapping and the three binds with no
        # mango counterpart (Mod+O and the two brightness keys).
        bind =
          [
            # Terminal, launcher, apps
            "SUPER,Return,spawn,${wezterm}"
            "SUPER,space,spawn,noctalia msg panel-toggle launcher"
            "SUPER,b,spawn,${pkgs.blueman}/bin/blueman-manager"
            "SUPER,p,spawn,${pkgs.pavucontrol}/bin/pavucontrol"
            "SUPER,n,spawn,${pkgs.kdePackages.dolphin}/bin/dolphin"
            "SUPER,l,spawn,${pkgs.systemd}/bin/loginctl lock-session"
            "SUPER+SHIFT,b,spawn,${inputs.zen-browser.packages.x86_64-linux.beta}/bin/zen-beta"
            "SUPER,y,spawn,${playClipboard}"
            # Instrument panel — see ../../sitrep-hud.nix.
            "SUPER,i,spawn,${sitrepHud}"
            "SUPER,g,spawn,${evenSplit}"

            # Format: appid,title,command — `none` for whichever field isn't
            # matched on. mango launches the command itself on first use and
            # toggles thereafter, so nothing is spawned-and-hidden at startup.
            "SUPER,t,toggle_named_scratchpad,org.telegram.desktop,none,telegram-sandboxed"
            "SUPER+SHIFT,Return,toggle_named_scratchpad,scratchpad-terminal,none,${wezterm} start --always-new-process --class scratchpad-terminal"
            "SUPER+SHIFT,t,toggle_scratchpad"

            # Window management
            "SUPER,q,killclient"
            "SUPER,f,togglefullscreen"
            "SUPER,m,togglemaximizescreen"
            "SUPER+SHIFT,space,centerwin"
            "SUPER,e,toggleoverview"
            "SUPER+SHIFT,e,quit"

            # Focus and move. Left/right walk the scroller strip; up/down walk the
            # stack inside a column, which is what niri's focus-window-up/down do.
            "SUPER,Left,focusdir,left"
            "SUPER,Right,focusdir,right"
            "SUPER,Up,focusdir,up"
            "SUPER,Down,focusdir,down"
            "SUPER+SHIFT,Left,exchange_client,left"
            "SUPER+SHIFT,Right,exchange_client,right"
            "SUPER+SHIFT,Up,exchange_client,up"
            "SUPER+SHIFT,Down,exchange_client,down"

            # Same convention as the tag keys: CTRL picks the monitor axis,
            # SHIFT carries the window along. focusdir/exchange_client stop at
            # the output edge, so without these a window can never leave the
            # display it opened on.
            "SUPER+CTRL,Left,focusmon,left"
            "SUPER+CTRL,Right,focusmon,right"
            "SUPER+CTRL+SHIFT,Left,tagmon,left"
            "SUPER+CTRL+SHIFT,Right,tagmon,right"

            # Screenshots
            "SUPER+SHIFT,s,spawn,${screenshot} region"
            "SUPER+SHIFT,d,spawn,${screenshot} screen"

            # Media and volume
            "NONE,XF86AudioRaiseVolume,spawn,${pkgs.pamixer}/bin/pamixer -i 5"
            "NONE,XF86AudioLowerVolume,spawn,${pkgs.pamixer}/bin/pamixer -d 5"
            "NONE,XF86AudioMute,spawn,${pkgs.pamixer}/bin/pamixer --toggle-mute"
            "NONE,XF86AudioPlay,spawn,${pkgs.playerctl}/bin/playerctl play-pause"
            "NONE,XF86AudioNext,spawn,${pkgs.playerctl}/bin/playerctl next"
            "NONE,XF86AudioPrev,spawn,${pkgs.playerctl}/bin/playerctl previous"
          ]
          # Mod+1..0 views a tag, Mod+Shift+1..0 sends the window to it — the same
          # ten keys niri binds to focus-workspace / move-window-to-workspace. `0`
          # is tag 10, which is why tag_num is 10 and not the mango default of 9.
          ++ lib.concatMap
          (i: let
            key =
              if i == 10
              then "0"
              else toString i;
          in [
            "SUPER,${key},view,${toString i}"
            "SUPER+SHIFT,${key},tag,${toString i}"
          ])
          (lib.range 1 tagCount);

        # --- Mouse ------------------------------------------------------------
        # The module emits only what is declared, so with no mousebind lines the
        # pointer couldn't move a window at all. A dropped drag is what crosses
        # outputs: on release mango re-homes the window to the monitor under the
        # cursor. Same chords as upstream's defaults, MINUS its bare
        # `NONE,btn_middle,togglemaximizescreen` — a modifier-less mousebind
        # still matches for the middle button, and a matched bind returns before
        # notifying the client, so the press never arrives: no paste, no
        # close-tab, just the window flipping maximize. Middle click belongs to
        # the app, and niri binds nothing to it either.
        mousebind = [
          "SUPER,btn_left,moveresize,curmove"
          "SUPER,btn_right,moveresize,curresize"
        ];
      };
    };
  };
}
