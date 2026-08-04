{ pkgs
, lib
, config
, ...
}:
let
  cfg = config.rices.niri.marquee;

  # The marquee (CONTEXT.md): a strip along the top of one output, permanently
  # removed from niri's working area and impossible for any window to cover,
  # whose tenant is a video. See docs/adr/0011-marquee-on-the-portrait-oled.md —
  # read it before changing anything here; several choices below look arbitrary
  # and are not.
  #
  # The reserve and the pixels are two independently-lived processes: an
  # always-on, module-less, opaque-black waybar owns the exclusive zone, and an
  # on-demand mpvpaper draws the video. That split is the whole point — a dead
  # video leaves a dark band instead of jolting every window on the panel up 810
  # px and back down.

  # 16:9 of the panel's logical width. The `/` needs the surrounding whitespace
  # or Nix parses it as a path; the division is exact (12960 / 16 = 810).
  depth = cfg.width * 9 / 16;

  # LAYERING. Three things stack on this panel: the wallpaper (reparented into
  # niri's backdrop by the layer-rule in ./niri.nix), waybar's black, and the
  # video on top. ADR-0011 asked for three *distinct* layer-shell levels so the
  # order would not depend on creation order. That turned out to be
  # unimplementable, in two steps:
  #
  #   - waybar cannot sit on `background`. Its deserializer understands only
  #     "bottom", "top" and "overlay" (src/bar.cpp:63-71, `enum bar_layer` at
  #     include/bar.hpp:32); anything else is silently ignored and the bar keeps
  #     its mode default, `bottom`. So waybar is on `bottom`.
  #   - "above `bottom`, still below normal windows" is an empty slot in the
  #     layer-shell protocol. `top` would put the video over fullscreen windows.
  #
  # So both live on `bottom`, and the order is creation order — which niri does
  # define: smithay's LayerMap is an insertion-ordered set and niri renders
  # `layers_on(layer).rev()` front-to-back (src/niri.rs:4392-4393), i.e. the most
  # recently mapped surface wins. The strut is always-on from graphical-session
  # and mpvpaper is started on demand, so the video always maps later and is
  # always on top. The one hole: restarting the strut while a tenant plays remaps
  # its black ABOVE the video (audio keeps playing, the band goes black) — go dark
  # and re-cast to fix it.

  niri = "${pkgs.niri-stable}/bin/niri"; # must match the compositor; see ./niri.nix
  jq = "${pkgs.jq}/bin/jq";
  head = "${pkgs.coreutils}/bin/head";
  systemctl = "${pkgs.systemd}/bin/systemctl";
  systemdRun = "${pkgs.systemd}/bin/systemd-run";
  systemdInhibit = "${pkgs.systemd}/bin/systemd-inhibit";
  notifySend = "${pkgs.libnotify}/bin/notify-send";
  socat = "${pkgs.socat}/bin/socat";
  waybar = "${pkgs.waybar}/bin/waybar";
  mpvpaper = "${pkgs.mpvpaper}/bin/mpvpaper";
  tofiBin = "${pkgs.tofi}/bin/tofi";
  wlPaste = "${pkgs.wl-clipboard}/bin/wl-paste";
  gawk = "${pkgs.gawk}/bin/gawk";

  # PANEL IDENTITY. Neither tool can be told about a panel by identity under
  # niri, so this is the one place that knows how, and only a connector name ever
  # reaches them:
  #
  #   - niri publishes each output's wl_output description as
  #     "<make> - <model> - <connector>" (niri-config/src/output.rs:112-119). It
  #     carries the connector and drops the serial — it is NOT wlroots'
  #     "make model serial (connector)".
  #   - waybar's `output` compares against the output name or that description
  #     with a trailing " (name)" stripped (src/config.cpp:190), and mpvpaper
  #     substring-matches the same two strings (src/main.c:728-730). So under
  #     niri there is no port-independent string either of them can match, and a
  #     kanshi-style make/model/serial criteria matches NOTHING — waybar just
  #     silently creates no bar.
  #
  # niri's own IPC does report make/model/serial separately, so `cfg.panel` stays
  # a single panel identity, byte-identical to its kanshi criteria, and gets
  # translated here. Prints nothing when the panel isn't connected.
  panelConnector = pkgs.writeShellScript "marquee-panel-connector" ''
    set -u
    ${niri} msg --json outputs 2>/dev/null \
      | ${jq} -r --arg want "${cfg.panel}" '
          to_entries[]
          | select(([.value.make, .value.model, .value.serial]
                    | map(. // "") | join(" ")) == $want)
          | .key
        ' \
      | ${head} -n 1
  '';

  # Opaque black, because this is the marquee's *dark* state (CONTEXT.md) and not
  # decoration: no window can ever cover this strip, which makes it the single
  # most burn-in-exposed region on the machine, and on an OLED dark means pixels
  # off. Passed with -s, so nothing lands in ~/.config/waybar and stylix has
  # nothing to fight (its waybar target is off anyway; see ./stylix.nix).
  strutStyle = pkgs.writeText "marquee-waybar-style.css" ''
    window#waybar {
      background-color: #000000;
    }
  '';

  # --- The reserve ----------------------------------------------------------
  # A bar with no modules, which exists only for its exclusive zone: niri v25.08
  # has no per-output layout override (`output { layout { … } }` fails `niri
  # validate` outright) and a global strut would take the same depth off every
  # other panel too, so a layer-shell exclusive zone is the one per-output
  # reserve available. `exclusive` is left at its default (true) — that IS the
  # mechanism, so don't set it.
  #
  # Not programs.waybar: that module writes the config at build time, and the
  # connector is only knowable at runtime (see PANEL IDENTITY above).
  strut = pkgs.writeShellScript "marquee-strut" ''
    set -u

    conn=$(${panelConnector})

    # An absent panel leaves $conn empty, which matches no output: waybar creates
    # no bar and picks the panel up by itself when it comes back on the same
    # connector — dock/undock and monitor-off, i.e. the common cases.
    conf="$XDG_RUNTIME_DIR/marquee-waybar.json"
    printf '[{"layer":"bottom","position":"top","height":%d,"output":["%s"],"modules-left":[],"modules-center":[],"modules-right":[]}]\n' \
      ${toString depth} "$conn" >"$conf"

    # A port change is the one case waybar can't ride out, because the connector
    # baked into that file is now stale. Re-resolve on every output change and
    # take the unit down when it moved; Restart=always brings us back with a
    # fresh one.
    main=$$
    (
      ${niri} msg --json event-stream 2>/dev/null | while IFS= read -r line; do
        case "$line" in
          *OutputsChanged*)
            if [ "$(${panelConnector})" != "$conn" ]; then
              kill "$main"
              exit 0
            fi
            ;;
        esac
      done
    ) &

    # exec so waybar becomes the unit's main process: the watcher's kill reaches
    # it, and a waybar crash restarts the unit — which re-resolves — by itself.
    exec ${waybar} -c "$conf" -s ${strutStyle}
  '';

  # mpv options as mpvpaper hands them over: it rewrites every space into a
  # newline and dumps the result into a throwaway mpv.conf
  # (src/main.c:429-447), so each entry is `key=value` — no leading dashes, and
  # no spaces anywhere inside one.
  #
  #   - video-align-y=-1 + keepaspect=yes top-align the 16:9 fit inside the
  #     full-output surface, so the video lands exactly on the reserved band.
  #     (mpvpaper hard-codes anchor-all-four-edges, set_size(0,0) and
  #     set_exclusive_zone(-1) at src/main.c:701-708 with no CLI escape, so the
  #     surface is always the whole output and the fit is the only lever. A
  #     tenant that isn't 16:9 is taller than the band and spills below it,
  #     behind the windows.)
  #   - ytdl-format caps the decode at the band's logical width: it is only
  #     2160x1215 physical (scale 1.5), so unrestricted `bestvideo` would decode
  #     2160p for a 1215px-tall strip.
  #   - ytdl_hook-ytdl_path is not optional. The unit runs under the systemd user
  #     manager, whose PATH is not the session's, so mpv would not find yt-dlp
  #     and every URL would fail.
  #   - input-ipc-server exists so playback controls (pause, seek, volume — never
  #     designed) can be added later without redesigning any of this.
  #
  # NEVER add `loop`: EOF must exit so the idle inhibitor is released and the
  # marquee darkens itself — a 40-minute video is a self-cleaning 40-minute
  # keep-awake. And never pass mpvpaper's own -p/-s: their "wallpaper is hidden"
  # heuristic misfires on a full-output surface that windows partially cover.
  mpvOptions = lib.concatStringsSep " " [
    "video-align-y=-1"
    "keepaspect=yes"
    "hwdec=auto"
    "ytdl-format=bestvideo[height<=?${toString cfg.width}]+bestaudio/best"
    "script-opts=ytdl_hook-ytdl_path=${pkgs.yt-dlp}/bin/yt-dlp"
    "input-ipc-server=$XDG_RUNTIME_DIR/marquee.sock"
  ];

  darkRow = "◼ Go dark";

  # --- Cast picker (Mod+Y) --------------------------------------------------
  # One key covers cast, replace and go-dark, because the rows ARE the current
  # state: "go dark" is offered only while a tenant is playing, and the clipboard
  # is offered only when it plausibly names something playable. Anything typed or
  # pasted is accepted (--require-match false), which is what makes casting a
  # single keystroke.
  #
  # Geometry, font and colours all come from ./tofi.nix — do not add --width,
  # --height or --anchor here. A sized tofi window is unreadable on this panel;
  # that file says why, with numbers.
  marqueeCast = pkgs.writeShellScript "marquee-cast" ''
    set -euo pipefail

    # Text/plain only, so an image on the clipboard can't become a binary menu
    # row. A multi-line paste is never a URL or a path.
    clip=$(${wlPaste} --no-newline --type text/plain 2>/dev/null || true)
    if [ "$(printf '%s' "$clip" | ${gawk} 'END { print NR }')" -gt 1 ]; then
      clip=""
    fi
    case "$clip" in
      http://*|https://*) ;;
      *) if [ ! -e "$clip" ]; then clip=""; fi ;;
    esac

    rows() {
      if ${systemctl} --user is-active --quiet niri-marquee.service; then
        printf '%s\n' "${darkRow}"
      fi
      if [ -n "$clip" ]; then
        printf '%s\n' "$clip"
      fi
    }

    # The placeholder is the instruction: with no tenant and nothing playable on
    # the clipboard the menu has no rows at all, and an empty prompt would look
    # broken rather than ready.
    pick=$(rows \
      | ${tofiBin} \
          --prompt-text "Marquee: " \
          --placeholder-text "paste or type a URL or path" \
          --require-match false) || exit 0
    [ -n "$pick" ] || exit 0

    if [ "$pick" = "${darkRow}" ]; then
      exec ${systemctl} --user stop niri-marquee.service
    fi

    # There is no marquee to cast into while the panel is elsewhere.
    conn=$(${panelConnector})
    if [ -z "$conn" ]; then
      exec ${notifySend} --app-name=marquee "Marquee" "panel is not connected"
    fi

    # Replacing a live tenant: the unit name is fixed, so a second systemd-run
    # would fail on "unit already exists". Stopping is also what releases the
    # outgoing tenant's idle inhibitor.
    ${systemctl} --user stop niri-marquee.service 2>/dev/null || true

    # --collect so a tenant that ran to EOF leaves no unit behind; OnFailure
    # notifies, because a dead or DRM-protected URL otherwise just leaves the
    # marquee dark with the reason buried in the journal. After= records the
    # layering requirement (see LAYERING above). Wants= pulls in the keep-awake,
    # which binds itself back to this unit — see niri-marquee-awake.service.
    #
    # mpvpaper takes the connector, not the panel identity — and by *substring*
    # (src/main.c:728-730), so never hand it a connector name that contains
    # another output's name (an internal "eDP-1" would also grab a "DP-1").
    exec ${systemdRun} --user --unit=niri-marquee --collect \
      --description="marquee tenant" \
      -p After=niri-marquee-strut.service \
      -p Wants=niri-marquee-awake.service \
      -p OnFailure=niri-marquee-failed.service \
      -- ${mpvpaper} -l bottom -o "${mpvOptions}" "$conn" "$pick"
  '';

  # --- Pause (Mod+Shift+Y) --------------------------------------------------
  # The one playback control that earns a key of its own. Everything else about
  # the marquee is state-shaped and belongs in the picker's rows; pause is
  # reflex-shaped, and a menu round-trip for it would be absurd.
  #
  # It drives mpv over the JSON IPC socket the tenant opens because of
  # `input-ipc-server` above.
  marqueePause = pkgs.writeShellScript "marquee-pause" ''
    set -u

    # Nothing to pause. The unit is the gate, not the socket file: mpv unlinks a
    # stale path before binding (mpv input/ipc-unix.c:326), so the socket outlives
    # the tenant that made it.
    ${systemctl} --user is-active --quiet niri-marquee.service || exit 0

    # niri-marquee-awake is active for exactly as long as the tenant is playing,
    # so it doubles as the pause state — no round trip needed to read it back.
    # The property is then set explicitly rather than with mpv's own
    # `cycle pause`, so the unit's idea of playing can't drift from mpv's.
    if ${systemctl} --user is-active --quiet niri-marquee-awake.service; then
      want=true
    else
      want=false
    fi

    printf '{"command":["set_property","pause",%s]}\n' "$want" \
      | ${socat} - "UNIX-CONNECT:$XDG_RUNTIME_DIR/marquee.sock" >/dev/null

    # Playback, not tenancy, is what holds the idle chain off. Releasing it while
    # paused is also the burn-in answer: a paused tenant is a static frame in a
    # band no window can ever cover, so swayidle's screensaver is exactly what
    # should come over it — at 300s, with the panel powering off at 900s.
    if [ "$want" = true ]; then
      ${systemctl} --user stop niri-marquee-awake.service
    else
      ${systemctl} --user start niri-marquee-awake.service
    fi
  '';
in
{
  # Machine policy: which panel carries the marquee and how wide it is. Both are
  # per-host facts, so they come from homes/<host>/ — the rice only derives the
  # depth. Null (the default) means this machine has no marquee, and nothing in
  # this file exists.
  options.rices.niri.marquee = lib.mkOption {
    default = null;
    description = "The marquee reserved on one output: which panel, and how wide it is.";
    type = lib.types.nullOr (lib.types.submodule {
      options = {
        panel = lib.mkOption {
          type = lib.types.str;
          description = ''
            The panel carrying the marquee, as make/model/serial — byte-identical
            to its kanshi `criteria`. Never a connector name; the connector is
            resolved at runtime (see PANEL IDENTITY in the let block).
          '';
        };
        width = lib.mkOption {
          type = lib.types.ints.positive;
          description = ''
            The panel's logical width in the orientation it actually runs in.
            The marquee's depth is 16:9 of this.
          '';
        };
      };
    });
  };

  config = lib.mkIf (config.rices.niri.enable && cfg != null) {
    systemd.user.services.niri-marquee-strut = {
      Unit = {
        Description = "Reserve the marquee band at the top of one output";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${strut}";
        Restart = "always";
        RestartSec = 1;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # The keep-awake, held for exactly as long as the tenant is *playing* rather
    # than for the whole tenancy (CONTEXT.md). Watching registers as no activity
    # at all and mpvpaper holds no inhibitor of its own, so without this
    # ./swayidle.nix would put the drift screensaver over the video at 300s and
    # suspend the machine at 1200s. swayidle drops all four of its timeouts while
    # any logind `idle` inhibitor is held, so one lock covers the whole chain —
    # the same lever ../../scripts/keep-awake.nix uses.
    #
    # BindsTo, so EOF, a crash and "go dark" all release it with nothing watching
    # for them: the tenant going inactive for ANY reason takes this down too. The
    # tenant pulls it in with `Wants=`; Mod+Shift+Y stops and starts it.
    systemd.user.services.niri-marquee-awake = {
      Unit = {
        Description = "Hold off idle while the marquee tenant plays";
        BindsTo = [ "niri-marquee.service" ];
        After = [ "niri-marquee.service" ];
      };
      Service.ExecStart = lib.concatStringsSep " " [
        systemdInhibit
        "--what=idle"
        "--who=marquee"
        ''--why="marquee playing"''
        "${pkgs.coreutils}/bin/sleep"
        "infinity"
      ];
    };

    # Failure channel for the tenant unit. A `systemctl stop` (going dark) ends
    # the unit cleanly, so this only fires on a tenant that actually broke.
    # Normal urgency deliberately: a critical notification never expires.
    systemd.user.services.niri-marquee-failed = {
      Unit.Description = "Report a marquee tenant that failed to play";
      Service = {
        Type = "oneshot";
        ExecStart = lib.concatStringsSep " " [
          notifySend
          "--app-name=marquee"
          "Marquee"
          ''"tenant failed — journalctl --user -u niri-marquee"''
        ];
      };
    };

    # Cast / replace / go dark, and pause. Both free against every bind in
    # ./niri.nix and ../../homes/tempest/soft-reboot.nix.
    programs.niri.settings.binds = {
      "Mod+Y".action.spawn = [ "${marqueeCast}" ];
      "Mod+Shift+Y".action.spawn = [ "${marqueePause}" ];
    };
  };
}
