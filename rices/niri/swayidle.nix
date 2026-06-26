{ pkgs, inputs, lib, config, ... }:
let
  colors = config.lib.stylix.colors;

  drift = pkgs.callPackage ../../packages/drift.nix { src = inputs.drift; };

  driftStart = pkgs.writeShellScript "drift-screensaver-start" ''
    ${pkgs.kitty}/bin/kitty --class=drift-screensaver -e ${drift}/bin/drift --scene waveform &
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
  lockNow = pkgs.writeShellScript "niri-lock" ''
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
  lockBeforeSleep = pkgs.writeShellScript "niri-lock-before-sleep" ''
    ${pkgs.procps}/bin/pidof swaylock > /dev/null 2>&1 || ${swaylock}
    # Small settle before the screen is frozen for s2idle.
    ${pkgs.coreutils}/bin/sleep 0.3
  '';
in
lib.mkIf config.rices.niri.enable {
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
        timeout = 900;
        command = "${pkgs.niri-unstable}/bin/niri msg action power-off-monitors";
        resumeCommand = "${pkgs.niri-unstable}/bin/niri msg action power-on-monitors";
      }
      {
        # 20 min: actually suspend. Nothing else here suspends on inactivity —
        # logind only acts on the lid — so without this the laptop just sits
        # with its screen off, fully awake and draining. s2idle (S0ix) is the
        # only suspend state this Framework exposes (firmware has no S3) and
        # ZFS root rules out hibernation, so plain suspend is the deep state.
        timeout = 1200;
        command = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];
    events = {
      before-sleep = "${lockBeforeSleep}";
      lock = "${lockNow}";
    };
  };
}
