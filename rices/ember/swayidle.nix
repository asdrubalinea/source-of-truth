{
  pkgs,
  inputs,
  lib,
  config,
  ...
}: let
  colors = config.lib.stylix.colors;

  drift = pkgs.callPackage ../../packages/drift.nix {src = inputs.drift;};

  # --always-new-process is load-bearing twice over: it keeps `--class` ours (a
  # plain `wezterm start` lets an already-running instance spawn the window,
  # which would carry that instance's app-id and miss the open-fullscreen window
  # rule matching ^drift-screensaver$), and it makes $! the PID of the process
  # that actually owns the window, so driftStop's kill closes the screensaver
  # instead of a client that already exited.
  driftStart = pkgs.writeShellScript "drift-screensaver-start" ''
    ${pkgs.wezterm}/bin/wezterm start --always-new-process --class drift-screensaver -- ${drift}/bin/drift --scene waveform &
    echo $! > "$XDG_RUNTIME_DIR/drift-screensaver.pid"
  '';

  # Every external here MUST be an absolute store path or a bash builtin. swayidle
  # runs its commands with the systemd user-manager PATH, which has no coreutils —
  # bare `cat`/`rm` here died with "command not found" on every single resume, so
  # `kill ""` never killed anything and the screensaver window leaked, forever.
  # `$(< file)` is the builtin read, which is why it needs no store path.
  driftStop = pkgs.writeShellScript "drift-screensaver-stop" ''
    pidfile="$XDG_RUNTIME_DIR/drift-screensaver.pid"
    if [ -f "$pidfile" ]; then
      kill "$(< "$pidfile")" 2>/dev/null || true
      ${pkgs.coreutils}/bin/rm -f "$pidfile"
    fi
  '';

  # The lock surface is swaylock, NOT Noctalia's lockscreen. Noctalia v5 is the
  # NNN "shell" leg (bar/launcher/notifications/wallpaper), but its
  # ext-session-lock client segfaults deterministically on output hotplug — and
  # docking IS output hotplug (eDP-1 off, externals on). So every lock taken while
  # docked crashed the locker; niri then had to keep the outputs locked with no
  # surface and painted its solid red fallback (the "red grape screen"), which the
  # auto-restarted locker just re-crashed into. swaylock is a tiny wlroots locker
  # that survives output hotplug and draws its prompt on every connected output.
  # This mirrors ADR 0007's cold-boot move OFF the Noctalia locker (to tuigreet);
  # here the runtime lock path follows the same reasoning. PAM service `swaylock`
  # is defined in ./system.nix.
  swaylockArgs = lib.concatStringsSep " " [
    "-f" # daemonize, but only AFTER the lock surface is up (see lockBeforeSleep)
    "--ignore-empty-password"
    "--show-failed-attempts"
    # NOT `--indicator`: swaylock 1.8.6 has no such option, and getopt_long's
    # prefix matching makes it *ambiguous* against the seven --indicator-* flags,
    # so swaylock printed its usage and exited 1 before ever touching Wayland.
    # Every lock since this line was added was a no-op: the idle `lock` event did
    # nothing, and lockBeforeSleep's inhibitor was released instantly, so the box
    # suspended unlocked and resumed straight to the desktop with no prompt.
    "--indicator-idle-visible"
    "--color ${colors.base00}"
    "--inside-color ${colors.base01}"
    "--inside-wrong-color ${colors.base08}"
    "--ring-color ${colors.base03}"
    "--ring-ver-color ${colors.base0D}"
    "--ring-wrong-color ${colors.base08}"
    "--key-hl-color ${colors.base0D}"
    "--bs-hl-color ${colors.base08}"
    "--text-color ${colors.base05}"
  ];
  swaylock = "${pkgs.swaylock}/bin/swaylock ${swaylockArgs}";

  # Single "lock now" entry point for the `lock` event. swayidle fires `lock` on
  # every logind Lock signal — emitted by `loginctl lock-session` from both the
  # 600s idle timer and the Mod+L bind. Guard against a second instance: only one
  # client may hold the ext-session-lock, so a duplicate swaylock just fails to
  # acquire it (and would exit non-zero, noise). swayidle's user-service PATH has
  # no profile, so pidof/swaylock are called by absolute store path.
  lockNow = pkgs.writeShellScript "ember-lock" ''
    ${pkgs.procps}/bin/pidof swaylock > /dev/null 2>&1 && exit 0
    exec ${swaylock}
  '';

  # before-sleep locker. swayidle holds the logind sleep inhibitor only until this
  # command RETURNS, so the lock must be fully up before we let go. `swaylock -f`
  # forks only after it has taken the lock and shown its surface, so a synchronous
  # call here is exactly that guarantee — no detour through `loginctl lock-session`
  # (whose Lock signal is handled on the *separate* `lock` event, off the
  # inhibitor-blocked path, and could let the box suspend before the surface is up
  # and resume unlocked — the bug we hit). Guarded so we don't double-launch over
  # an already-running swaylock from the idle path.
  lockBeforeSleep = pkgs.writeShellScript "ember-lock-before-sleep" ''
    ${pkgs.procps}/bin/pidof swaylock > /dev/null 2>&1 || ${swaylock}
    # Small settle before the screen is frozen for s2idle.
    ${pkgs.coreutils}/bin/sleep 0.3
  '';

  # --- Monitor power, per session ------------------------------------------
  # swayidle is furniture: ONE user service, wanted by graphical-session.target,
  # which both compositor layers reach. Every other command here is
  # compositor-agnostic (swaylock, wezterm, systemctl); powering the panels off is
  # not, and there is no shared protocol for it either — niri exposes it as an IPC
  # action, mango as an mmsg dispatch, per output.
  #
  # Rather than duplicate the unit per session, branch on the socket each
  # compositor exports into the session environment. That variable is the same
  # thing Noctalia detects on (CompositorKind in compositor_detect.cpp), so the
  # test is the ecosystem's convention, not a guess.
  #
  # niri-unstable must match the running compositor or `niri msg` refuses to talk
  # to it (see the `niri` binding in compositors/niri/niri.nix). mango's dispatch
  # is per-monitor with no "all" form, so we enumerate what it reports; the loop
  # is a no-op if it reports nothing, which is the right behaviour for a session
  # with no outputs rather than an error. `get all-monitors` answers with a
  # {"monitors":[...]} wrapper, not a bare array — filtering `.[].name` makes jq
  # error out and the loop silently never runs (the bug that left mango's panels
  # on while niri's went dark).
  #
  # NEVER TOUCH A MONITOR KANSHI DISABLED. `get all-monitors` lists every monitor
  # mango knows, including the ones kanshi has *disabled* (eDP-1 in every docked
  # profile), and `wakeup_monitor` is unconditional — it sets enabled=true and
  # clears only_sleep. Wake the lid panel that way and, because it was removed
  # from the layout when kanshi disabled it, mango re-adds it with
  # `wlr_output_layout_add_auto`: wherever mango picks, not where kanshi put it.
  # That is the "resume, layout is fucked, restart kanshi" bug.
  #
  # niri's power-on-monitors distinguishes "powered off" from "disabled"; mango's
  # sleep/wake pair does not — but mango's *state* does, and reports it. Both
  # sleep_monitor and a kanshi disable set enabled=false, yet updatemons only
  # drops the output from the layout when only_sleep is 0, so:
  #
  #   kanshi-disabled → out of the layout → mmsg reports width/height 0
  #   slept by us     → stays in the layout → mmsg reports its real geometry
  #
  # "Stays in the layout" only holds with the only_sleep patch applied in
  # flake.nix (packages/patches/mango-outputmgr-keeps-only-sleep.patch).
  # Unpatched, any kanshi profile re-apply — and sleeping the bus-powered
  # portable panel CAUSES one, because DPMS-off drops it off the bus and it
  # reconnects a second later — cleared only_sleep on every head kanshi
  # re-committed as disabled; updatemons then ejected the slept QD-OLED from
  # the layout and this filter hid it from `on` forever (the 2026-08-19
  # black-OLED-until-mango-dies bug).
  #
  # `select(.width > 0)` is therefore exactly "monitors this session is allowed to
  # drive", for both directions, with no state to keep between the two calls — a
  # swayidle restart mid-sleep can't strand the session with black panels, and
  # `on` can't light up a panel kanshi deliberately turned off. (`active` is not
  # the flag to test: in mmsg it means "is the selected monitor".)
  monitorPower = pkgs.writeShellScript "ember-monitor-power" ''
    set -u
    case "''${1:-off}" in
      off) niri_action=power-off-monitors; mango_action=sleep_monitor ;;
      on)  niri_action=power-on-monitors;  mango_action=wakeup_monitor ;;
      *) exit 2 ;;
    esac

    if [ -n "''${NIRI_SOCKET:-}" ]; then
      exec ${pkgs.niri-unstable}/bin/niri msg action "$niri_action"
    elif [ -n "''${MANGO_INSTANCE_SIGNATURE:-}" ]; then
      ${pkgs.mango}/bin/mmsg get all-monitors \
        | ${pkgs.jq}/bin/jq -r '.monitors[] | select(.width > 0) | .name' \
        | while read -r mon; do
            ${pkgs.mango}/bin/mmsg dispatch "$mango_action,$mon" || true
          done
    fi
  '';

  # On AC power we keep the machine awake (services like the auxologico bot keep
  # running, backups complete) but the screens still power off via the 120s
  # timer; only on battery do we actually suspend. swayidle's suspend timeout
  # (1200s) runs this wrapper instead of a bare `systemctl suspend`. The check
  # reads sysfs directly (no extra deps): suspend only when EVERY real battery
  # reports Discharging. On mains the battery reads Charging / Full / Not
  # charging, so the wrapper no-ops and the desktop just sits with screens off,
  # fully awake — the Framework has no S3, so s2idle is the deep state, which is
  # exactly what we want to avoid while charging.
  #
  # `BAT*`, not `*`: peripheral batteries land in the same directory
  # (hidpp_battery_N for the Logitech receiver, controller batteries, …) and a
  # mouse sitting at Full would short-circuit the loop and veto every suspend.
  # Same absolute-path rule as driftStop above — `$(< …)` is the bash builtin;
  # the bare `cat` this used to call was never on swayidle's PATH, so the read
  # returned empty, the != test passed and this ALWAYS exited 0. Idle suspend on
  # battery has never once fired.
  suspendOrOnBattery = pkgs.writeShellScript "ember-suspend-or-not" ''
    for s in /sys/class/power_supply/BAT*/status; do
      [ -r "$s" ] || continue
      [ "$(< "$s")" != "Discharging" ] && exit 0
    done
    exec ${pkgs.systemd}/bin/systemctl suspend
  '';
in
  lib.mkIf config.rices.ember.enable {
    # Lock is handled by swaylock (NOT Noctalia's lockscreen — see the let block for
    # why). swayidle owns the idle timers + the logind lock/sleep events below.
    # before-sleep locks swaylock synchronously (see lockBeforeSleep); the `lock`
    # event locks on idle (600s lock-session) and manual `loginctl lock-session`.
    services.swayidle = {
      enable = true;
      systemdTargets = ["graphical-session.target"];
      timeouts = [
        {
          timeout = 300;
          command = "${driftStart}";
          resumeCommand = "${driftStop}";
        }
        {
          timeout = 600;
          command = "${pkgs.systemd}/bin/loginctl lock-session";
        }
        {
          # OLED anti burn-in: power the panels off early (120s). This is the
          # earliest timer on purpose — a dark, off panel is the best burn-in
          # protection, so the drift screensaver (300s) and idle lock (600s)
          # below are effectively unreachable in the on-screen state, but kept
          # for the manual/rental paths where the screen is left on.
          # Powering panels off is the one thing in this file only the compositor
          # can do, and swayidle is furniture — one user service, started by
          # graphical-session.target under whichever session you logged into. So the
          # command is a dispatcher (see monitorPower in the let block) rather than
          # a compositor's CLI, and this timer works unchanged in both.
          timeout = 120;
          command = "${monitorPower} off";
          resumeCommand = "${monitorPower} on";
        }
        {
          # 20 min: suspend on battery only. On AC the wrapper above no-ops (the
          # machine stays awake with screens off, so services keep running); on
          # battery it falls through to systemctl suspend and the box drops to
          # s2idle (S0ix), the only suspend state this Framework exposes. Nothing
          # else here suspends on inactivity — logind only acts on the lid — so
          # without this the laptop would just sit with its screen off on battery,
          # fully awake and draining.
          timeout = 1200;
          command = "${suspendOrOnBattery}";
        }
      ];
      events = {
        before-sleep = "${lockBeforeSleep}";
        lock = "${lockNow}";

        # The manual "restart kanshi after every resume" step, automated. Resuming
        # from s2idle re-enumerates the external panels (USB4/DP tunnels come back),
        # and mango enables a freshly-created output by default and places it with
        # layout_add_auto — so the lid panel lights up and the geometry is whatever
        # mango chose. kanshi does NOT fix this on its own: its match ignores
        # enabled/mode/position, so `current_profile` still matches the new head set
        # and match_and_apply keeps it and re-applies nothing.
        #
        # `kanshictl reload` is the smallest thing that does fix it — it clears
        # current_profile before re-matching, forcing a full commit of the profile's
        # enable/mode/position/scale. Same effect as the systemctl restart, without
        # dropping the wayland connection. Harmless under niri, which is why it can
        # live here in the shared unit rather than behind a compositor test.
        after-resume = "${pkgs.kanshi}/bin/kanshictl reload";
      };
    };

    # Panels went dark 120s into a video, because Chrome takes no Wayland idle
    # inhibitor for ordinary in-page playback. The inhibit path itself is sound —
    # proved in a headless nested mango, where a 3s swayidle timeout fired on the
    # dot with nothing held and never fired at all while wlinhibit held one — so
    # mango honours inhibitors and swayidle obeys them (its timeouts register with
    # obey_inhibitors = true; only its internal 0s resume probe uses the
    # input-idle variant that ignores them). The gap is app-side, and closing it
    # app-side means one rule per browser, forever.
    #
    # So inhibit on the thing every video actually has in common: sound.
    #
    # This was `sway-audio-idle-inhibit` until 2026-08-19, and that NEVER WORKED.
    # Despite the name and the nixpkgs description ("Prevent swayidle/hypridle from
    # sleeping"), the 0.2.0 build contains no Wayland client at all:
    #
    #   ldd + /proc/<pid>/maps → libpulse, libdbus, libsystemd, no libwayland
    #   grep -ao zwp_idle_inhibit… → nothing
    #   grep -ao org.freedesktop.login1.Manager → present
    #
    # It takes a *logind* idle inhibitor (visible as `systemd-inhibit --list` →
    # idle/block "Audio is playing"). swayidle's timers come from the Wayland idle
    # protocol; logind's idle inhibitor is invisible to them, so every video since
    # the daemon was added still hit the 120s power-off. The nested-mango test above
    # validated `wlinhibit` — a real Wayland client — which is why it looked proven.
    # Lesson: verify the protocol, not the package name.
    #
    # wayland-pipewire-idle-inhibit is the real thing — it binds
    # zwp_idle_inhibit_manager_v1 and reads pipewire directly, so it covers Chrome,
    # Firefox and mpv alike with no per-app rules. `-w` is passed explicitly even
    # though wayland is already the default backend: the whole reason this file
    # needed rewriting is a silent inhibitor backend, so the one that matters is
    # spelled out rather than inherited.
    #
    # -d 5 (the default) only inhibits for streams longer than 5s, which keeps
    # notification blips and UI clicks from holding the panels awake — strictly
    # better than the old daemon's "any non-corked sink-input".
    #
    # Ceiling: a muted or silent video produces no pipewire stream and will still
    # time out. If that turns up in practice the next rung is mango's own
    # `idleinhibit_when_focus` window rule, but that inhibits whenever the window
    # is focused (video or not), which is a much worse deal for the panels.
    #
    # Being a genuine Wayland client, this one now dies with the compositor — so it
    # is in the restart-policy list in homes/tempest/default.nix alongside swayidle
    # and kanshi. The old logind-only daemon never needed that, which is exactly why
    # it survived a mango restart looking healthy while doing nothing.
    systemd.user.services.wayland-pipewire-idle-inhibit = {
      Unit = {
        Description = "Hold a Wayland idle inhibitor while pipewire is playing audio";
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${pkgs.wayland-pipewire-idle-inhibit}/bin/wayland-pipewire-idle-inhibit -w";
        Restart = "always";
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  }
