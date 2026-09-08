{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.rices.ember.marquee;

  # The marquee (CONTEXT.md): a strip along the top of one output, permanently
  # removed from niri's working area and impossible for any window to cover,
  # whose tenant is a video. READ ADR 0011 before changing anything here —
  # several choices below look arbitrary and are not.
  #
  # The reserve and the pixels are two independently-lived processes: an
  # always-on, module-less, opaque-black waybar owns the exclusive zone, and an
  # on-demand mpvpaper draws the video. That split is the point — a dead video
  # leaves a dark band instead of jolting every window on the panel up 810px
  # and back down.

  # 16:9 of the panel's logical width. The `/` needs the surrounding whitespace
  # or Nix parses it as a path; the division is exact (12960 / 16 = 810).
  depth = cfg.width * 9 / 16;

  # LAYERING. Strut's black on `bottom`, video on `top`. This is about *motion*,
  # not stacking: niri renders `background`/`bottom` once PER RENDERED WORKSPACE,
  # cropped into that workspace's geometry — which is what puts the wallpaper
  # inside each overview card, and which made a `bottom` video scroll off the
  # panel on every workspace switch while a second copy scrolled in. `top` and
  # `overlay` are collected once, outside that loop, so they never move. A strip
  # that slides away is not a marquee.
  #
  # ADR 0011 rejected `top` for putting the video over fullscreen windows. Three
  # checked facts say it doesn't: niri renders the active workspace above the top
  # layer when the focused window is fullscreen; everything outside the video
  # rectangle is TRANSPARENT, not black (mpvpaper requests an alpha channel and a
  # #00000000 background — now load-bearing, see the mpvOptions warning); and
  # mpvpaper commits an empty input region, so clicks pass through.
  #
  # Two order dependencies remain. The strut stays on `bottom` — waybar's
  # deserializer knows only bottom/top/overlay and silently ignores anything
  # else — and the video is above it by *layer* now, so restarting the strut
  # mid-tenancy no longer buries it (ADR 0011's residual hole, closed). And
  # Noctalia's bar and screen corners are also on `top` here and map first;
  # niri renders most-recently-mapped first, and the tenant is cast on demand,
  # so a playing tenant covers them ON THIS PANEL only.

  niri = "${pkgs.niri-unstable}/bin/niri"; # must match the compositor; see ./niri.nix
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
  # Plain pkgs.yt-dlp 403s on nearly every YouTube video now, and a band fed a
  # YouTube link is the common case — see ../../../../packages/yt-dlp-pot.nix.
  ytDlp = pkgs.callPackage ../../../../packages/yt-dlp-pot.nix {};
  gawk = "${pkgs.gawk}/bin/gawk";

  # PANEL IDENTITY. Under niri, neither waybar nor mpvpaper can be told about a
  # panel by identity, so this is the one place that translates one, and only a
  # connector name ever reaches them. niri publishes wl_output descriptions as
  # "<make> - <model> - <connector>" — carrying the connector, dropping the
  # serial, and NOT wlroots' "make model serial (connector)" — and both tools
  # only match the output name or that description. So a kanshi-style
  # make/model/serial criteria matches NOTHING here, and waybar's failure mode is
  # to silently create no bar.
  #
  # niri's IPC does report make/model/serial separately, which is what lets
  # `cfg.panel` stay a single identity byte-identical to its kanshi criteria.
  # Prints nothing when the panel isn't connected.
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

  # Opaque black because this is the marquee's *dark* state, not decoration: no
  # window can ever cover this strip, making it the most burn-in-exposed region
  # on the machine, and on OLED dark means pixels off. Passed with -s so nothing
  # lands in ~/.config/waybar for stylix to fight.
  strutStyle = pkgs.writeText "marquee-waybar-style.css" ''
    window#waybar {
      background-color: #000000;
    }
  '';

  # --- The reserve ----------------------------------------------------------
  # A bar with no modules, existing only for its exclusive zone: niri has no
  # per-output layout override, and a global strut would take the same depth off
  # every other panel, so a layer-shell exclusive zone is the only per-output
  # reserve available. `exclusive` is left at its default true — that IS the
  # mechanism, so don't set it.
  #
  # Not programs.waybar: that writes the config at build time, and the connector
  # is only knowable at runtime (see PANEL IDENTITY above).
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
  # newline and dumps the result into a throwaway mpv.conf, so each entry is
  # `key=value` — no leading dashes, no spaces inside one.
  #
  #   - video-align-y=-1 + keepaspect=yes top-align the 16:9 fit, so the video
  #     lands exactly on the reserved band. mpvpaper hard-codes a full-output
  #     surface with no CLI escape, so the fit is the only lever — and a tenant
  #     that isn't 16:9 spills below the band, behind the windows.
  #   - ytdl-format caps the decode at the band's logical width; unrestricted
  #     `bestvideo` would decode 2160p for a 1215px-tall strip.
  #   - ytdl_hook-ytdl_path is not optional: the unit runs under the systemd user
  #     manager, whose PATH is not the session's, so mpv would never find yt-dlp.
  #   - input-ipc-server is what Mod+Shift+Y drives.
  #
  # NEVER add `loop`: EOF must exit so the idle inhibitor is released and the
  # marquee darkens itself — a 40-minute video is a self-cleaning 40-minute
  # keep-awake. Never pass mpvpaper's own -p/-s either; their "wallpaper is
  # hidden" heuristic misfires on a partially-covered full-output surface.
  #
  # And NEVER give the surface an opaque background — no `background-color` with
  # non-zero alpha, no `border-background=color` paired with one. The surface is
  # the whole output and it is on `top` (see LAYERING), so only the video
  # rectangle may be opaque or the tenant blacks out every window on this panel.
  # If that happens, Mod+Y → "Go dark" ends it.
  mpvOptions = lib.concatStringsSep " " [
    "video-align-y=-1"
    "keepaspect=yes"
    "hwdec=auto"
    "ytdl-format=bestvideo[height<=?${toString cfg.width}]+bestaudio/best"
    "script-opts=ytdl_hook-ytdl_path=${ytDlp}/bin/yt-dlp"
    "input-ipc-server=$XDG_RUNTIME_DIR/marquee.sock"
  ];

  darkRow = "◼ Go dark";

  # --- Cast picker (Mod+Y) --------------------------------------------------
  # One key covers cast, replace and go-dark, because the rows ARE the current
  # state: "go dark" appears only while a tenant plays, the clipboard row only
  # when it plausibly names something playable. --require-match false is what
  # makes casting a single keystroke.
  #
  # Geometry, font and colours come from ./tofi.nix — do not add --width,
  # --height or --anchor here; that file says why, with numbers.
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

    # --collect so a tenant that ran to EOF leaves no unit behind. OnFailure
    # notifies, because a dead or DRM-protected URL otherwise leaves the marquee
    # dark with the reason buried in the journal. After= is about the *reserve*,
    # not stacking: a tenant cast before the band exists would hang over windows
    # laid out as if it weren't there. Wants= pulls in the keep-awake, which
    # binds itself back to this unit.
    #
    # mpvpaper takes the connector and matches it by SUBSTRING, so never hand it
    # a name contained in another output's (an "eDP-1" would also grab "DP-1").
    exec ${systemdRun} --user --unit=niri-marquee --collect \
      --description="marquee tenant" \
      -p After=niri-marquee-strut.service \
      -p Wants=niri-marquee-awake.service \
      -p OnFailure=niri-marquee-failed.service \
      -- ${mpvpaper} -l top -o "${mpvOptions}" "$conn" "$pick"
  '';

  # --- Pause (Mod+Shift+Y) --------------------------------------------------
  # The one playback control that earns its own key: everything else about the
  # marquee is state-shaped and belongs in the picker's rows, but pause is
  # reflex-shaped. Drives mpv over the `input-ipc-server` socket above.
  marqueePause = pkgs.writeShellScript "marquee-pause" ''
    set -u

    # Nothing to pause. The unit is the gate, not the socket file: mpv unlinks a
    # stale path before binding (mpv input/ipc-unix.c:326), so the socket outlives
    # the tenant that made it.
    ${systemctl} --user is-active --quiet niri-marquee.service || exit 0

    # niri-marquee-awake is active exactly while the tenant plays, so it doubles
    # as the pause state — no round trip to read it back. The property is set
    # explicitly rather than via mpv's `cycle pause`, so the unit's idea of
    # playing can't drift from mpv's.
    if ${systemctl} --user is-active --quiet niri-marquee-awake.service; then
      want=true
    else
      want=false
    fi

    printf '{"command":["set_property","pause",%s]}\n' "$want" \
      | ${socat} - "UNIX-CONNECT:$XDG_RUNTIME_DIR/marquee.sock" >/dev/null

    # Playback, not tenancy, holds the idle chain off. Releasing it while paused
    # is also the burn-in answer: a paused tenant is a static frame in a band no
    # window can cover, so swayidle is exactly what should come over it.
    if [ "$want" = true ]; then
      ${systemctl} --user stop niri-marquee-awake.service
    else
      ${systemctl} --user start niri-marquee-awake.service
    fi
  '';
in {
  # Machine policy: which panel carries the marquee and how wide it is, both
  # per-host facts from homes/<host>/ — the rice only derives the depth. Null
  # (the default) means no marquee, and nothing in this file exists.
  options.rices.ember.marquee = lib.mkOption {
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

  config = lib.mkIf (config.rices.ember.niri.enable && cfg != null) {
    systemd.user.services.niri-marquee-strut = {
      Unit = {
        Description = "Reserve the marquee band at the top of one output";
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${strut}";
        Restart = "always";
        RestartSec = 1;
      };
      Install.WantedBy = ["graphical-session.target"];
    };

    # The keep-awake, held exactly while the tenant *plays*, not for the whole
    # tenancy. Watching registers as no activity and mpvpaper holds no inhibitor
    # of its own, so without this the panels would go off under the video at
    # 120s. swayidle drops all four timeouts while any logind `idle` inhibitor
    # is held, so one lock covers the chain — the lever keep-awake.nix uses too.
    #
    # BindsTo, so EOF, a crash and "go dark" all release it with nothing
    # watching for them. The tenant pulls it in with Wants=.
    systemd.user.services.niri-marquee-awake = {
      Unit = {
        Description = "Hold off idle while the marquee tenant plays";
        BindsTo = ["niri-marquee.service"];
        After = ["niri-marquee.service"];
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
      "Mod+Y".action.spawn = ["${marqueeCast}"];
      "Mod+Shift+Y".action.spawn = ["${marqueePause}"];
    };
  };
}
