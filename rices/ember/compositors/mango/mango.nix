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

  # niri has a built-in `screenshot` action; mango has none, so the two screenshot
  # binds go through grim/slurp. A script rather than an inline command because
  # mango's bind parser splits on commas and the save-then-copy pipeline would
  # have to survive that intact — one store path can't.
  screenshot = pkgs.writeShellScript "ember-screenshot" ''
    set -euo pipefail
    dir="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
    ${pkgs.coreutils}/bin/mkdir -p "$dir"
    file="$dir/$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S).png"
    case "''${1:-region}" in
      region) ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$file" ;;
      screen) ${pkgs.grim}/bin/grim "$file" ;;
      *) exit 2 ;;
    esac
    ${pkgs.wl-clipboard}/bin/wl-copy < "$file"
  '';

  wezterm = "${pkgs.wezterm}/bin/wezterm";

  # Every tag gets the scroller layout. mango is tag-based (a dwl inheritance):
  # unlike niri's dynamic per-output workspaces, the ten tags always exist, a
  # window can be on several at once, and an empty tag does not disappear. Ten of
  # them so Mod+1..0 lands on the same tag it lands on under niri.
  tagCount = 10;
  tagRules = map (i: "id:${toString i},layout_name:scroller") (lib.range 1 tagCount);
in {
  config = lib.mkIf (cfg.enable && cfg.mango.enable) {
    # mango re-reads config.conf only when told to (there is no inotify watch in
    # its source), and the file it reads is a store symlink — the inode never
    # changes in place, activation swaps the link. So poke it once the new
    # generation is linked and `nh home switch` alone is enough to apply a config
    # edit. `|| true` because this also runs from the niri session, from a TTY,
    # and on a first activation before any compositor exists, where mmsg has no
    # socket to talk to and must not fail the switch.
    home.activation.reloadMango = lib.hm.dag.entryAfter ["linkGeneration"] ''
      run ${pkgs.mango}/bin/mmsg dispatch reload_config > /dev/null 2>&1 || true
    '';

    wayland.windowManager.mango = {
      enable = true;

      # Pinned to the same derivation the system session runs
      # (./system.nix, programs.mango.package) and the same one
      # ../../swayidle.nix calls `mmsg` from. mango's IPC socket is versionless,
      # so a mismatch here fails at runtime rather than at build — which is
      # exactly the class of bug the niri layer's package comment describes.
      package = pkgs.mango;

      # MUST be non-empty. The HM module only writes autostart.sh — and only adds
      # the `exec-once` line that runs it — when this option is set; and that
      # script is where `dbus-update-activation-environment` and `systemctl --user
      # start mango-session.target` live. An empty autostart therefore means
      # graphical-session.target never starts, and the entire rest of the rice
      # (Noctalia, swayidle, kanshi) silently never launches.
      #
      # Nothing else belongs here: Noctalia runs as a supervised systemd user
      # service (../../noctalia.nix), and the scratchpads launch lazily on their
      # first toggle instead of being spawned and hidden at startup the way the
      # niri layer has to do it.
      autostart_sh = ''
        # (systemd/D-Bus activation is prepended by the module itself)
      '';

      settings = {
        # --- Session environment ------------------------------------------
        # Mirrors the niri layer's environment block. XDG_CURRENT_DESKTOP is the
        # one value that must differ: it is how portals pick a backend, and how
        # Noctalia identifies the compositor when MANGO_INSTANCE_SIGNATURE is not
        # visible to it.
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
          # Noctalia's lockscreen authenticates against this PAM service rather
          # than `login`, which refuses an unprivileged caller. The service is
          # defined in ../../system.nix; the env var has to be set per session,
          # which is why it appears in both compositor layers.
          "NOCTALIA_PAM_SERVICE,noctalia"
        ];

        # --- Tags and layout ----------------------------------------------
        tag_num = tagCount;
        tagrule = tagRules;

        # Scroller tuned to match niri's `default-column-width.proportion = 1.0`:
        # one full-width column at a time, scrolled horizontally. structs is the
        # sliver mango normally reserves at the sides to reveal the neighbouring
        # window; niri reveals nothing at proportion 1.0, so it goes to 0.
        scroller_default_proportion = 1.0;
        scroller_structs = 0;
        scroller_proportion_preset = "0.5,0.8,1.0";

        # --- Dimensions ----------------------------------------------------
        # niri: gaps 8 with struts -8 on left/right/bottom, i.e. 8px between
        # windows and none at the screen edge. mango splits that into inner and
        # outer directly, so it needs no negative-strut trick.
        borderpx = 2;
        gappih = 8;
        gappiv = 8;
        gappoh = 0;
        gappov = 0;
        border_radius = 12; # matches the bar's frameRadius, as niri's does
        smartgaps = 0;

        # --- Effects -------------------------------------------------------
        # scenefx can do considerably more than niri can (blur, per-window
        # opacity); deliberately not used. The brief was "the same desktop,
        # different engine", and niri draws no blur and shadows floating windows
        # only — which is exactly this.
        blur = 0;
        shadows = 1;
        shadow_only_floating = 1;
        focused_opacity = 1.0;
        unfocused_opacity = 1.0;

        # --- Colours -------------------------------------------------------
        # Derived from the stylix scheme (ember-3400k-dark), same two values the
        # niri layer uses for its borders: active base03 at 45%, inactive base01
        # at 15%. Noctalia ships its own mango colour template — leave it OFF, it
        # would try to write into ~/.config/mango, which Home Manager owns as a
        # read-only store symlink.
        #
        # Everything from urgentcolor down to splitcolor is *also* a border
        # colour — mango swaps the border to it while a window is in that state —
        # so they get the same 73 the focused border does. At ff they were the
        # one thing on an OLED panel glowing at full brightness against
        # near-black. rootcolor/shadowscolor aren't borders and stay opaque.
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
        # The compositor-drawn cursor. Must match stylix.cursor in ../../stylix.nix
        # (which themes the client-drawn ones) or the pointer changes appearance
        # depending on which surface it is over. Unset, wlroots falls back to the
        # X11 core cursor.
        cursor_theme = "Bibata-Modern-Classic";
        cursor_size = 20;

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
        # Same keys as the niri layer wherever the action exists on both sides;
        # see docs/mango-vs-niri.md for the full mapping and the four binds that
        # have no mango counterpart (Mod+G even-split, Mod+O audio switcher, and
        # the two brightness keys).
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

            # Scratchpads. Format: appid,title,command — `none` for whichever field
            # is not being matched on. mango launches the command itself on first
            # use and toggles visibility thereafter, so unlike the niri layer there
            # is nothing to spawn-and-hide at startup.
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

            # Monitors. Same convention as the tag keys: CTRL picks the monitor
            # axis, SHIFT carries the focused window along. focusdir/exchange_client
            # above stop at the output edge, so without these a window can never
            # leave the display it opened on.
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
        # The module only emits what is declared, so with no mousebind lines the
        # pointer could not move a window at all. Dropping a dragged window is
        # what actually crosses outputs: on button release mango calls
        # setmon(grabc, xytomon(cursor)) and re-tags the window if the target
        # tag changed, so a drag onto the second display lands there. Same
        # chords as upstream's defaults, minus upstream's bare
        # `NONE,btn_middle,togglemaximizescreen`: a modifier-less mousebind still
        # matches for the middle button (buttonpress() only exempts left/right),
        # and a matched bind returns before wlr_seat_pointer_notify_button, so
        # the press never reaches the client — no paste, no close-tab, just the
        # window flipping in and out of maximize. Middle click belongs to the
        # app; niri binds nothing to it either.
        mousebind = [
          "SUPER,btn_left,moveresize,curmove"
          "SUPER,btn_right,moveresize,curresize"
        ];
      };
    };
  };
}
