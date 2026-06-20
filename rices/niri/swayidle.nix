{ pkgs, inputs, lib, config, ... }:
let
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

  # Absolute path to the noctalia binary. swayidle's user-service PATH is ONLY
  # bash-interactive/bin (no profile, no home.packages), so a bare `noctalia` in
  # an event/timeout command is "command not found" and the lock silently
  # no-ops — which is exactly why suspend and the 600s idle timer stopped
  # locking. config.programs.noctalia.package is set in ./noctalia.nix (same HM
  # config).
  noctaliaBin = "${config.programs.noctalia.package}/bin/noctalia";

  # before-sleep locker. Locks the session DIRECTLY here rather than via
  # `loginctl lock-session`: swayidle holds the logind sleep inhibitor only until
  # this command returns, so the lock must complete on this path. Routing through
  # lock-session would emit a Lock signal handled on swayidle's *separate* `lock`
  # event, off the inhibitor-blocked path — the box could suspend before the lock
  # surface is up and resume unlocked (the bug we hit). `noctalia msg session
  # lock` also flips logind's LockedHint, so the hint stays correct without the
  # detour.
  lockBeforeSleep = pkgs.writeShellScript "niri-lock-before-sleep" ''
    ${noctaliaBin} msg session lock
    # Let the ext-session-lock surface draw before the screen is frozen for s2idle.
    ${pkgs.coreutils}/bin/sleep 0.5
  '';
in
lib.mkIf config.rices.niri.enable {
  # Lock is handled by Noctalia's lockscreen (NNN stack) rather than swaylock.
  # swayidle still owns the idle timers + the logind lock/sleep events below.
  # before-sleep locks Noctalia directly (see lockBeforeSleep); the `lock` event
  # locks on idle (600s lock-session) and manual `loginctl lock-session`. Both
  # call noctalia by ABSOLUTE path — bare `noctalia` isn't on swayidle's PATH.
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
      lock = "${noctaliaBin} msg session lock";
    };
  };
}
