{ pkgs, inputs, lib, config, ... }:
let
  colors = config.lib.stylix.colors;

  drift = pkgs.callPackage ../../packages/drift.nix { src = inputs.drift; };

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

  driftStop = pkgs.writeShellScript "drift-screensaver-stop" ''
    pidfile="$XDG_RUNTIME_DIR/drift-screensaver.pid"
    if [ -f "$pidfile" ]; then
      kill "$(cat "$pidfile")" 2>/dev/null || true
      rm -f "$pidfile"
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
    "--indicator"
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
  # with no outputs rather than an error.
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
        | ${pkgs.jq}/bin/jq -r '.[].name // empty' \
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
  suspendOrOnBattery = pkgs.writeShellScript "ember-suspend-or-not" ''
    for s in /sys/class/power_supply/*/status; do
      [ -r "$s" ] || continue
      [ "$(cat "$s")" != "Discharging" ] && exit 0
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
    systemdTargets = [ "graphical-session.target" ];
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
    };
  };
}
