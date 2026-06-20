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
in
lib.mkIf config.rices.niri.enable {
  # Lock is handled by Noctalia's lockscreen (NNN stack) rather than swaylock.
  # swayidle still owns the idle timers + the logind lock/sleep events below;
  # its `lock` event just calls into the already-running noctalia shell.
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
      before-sleep = "${pkgs.systemd}/bin/loginctl lock-session";
      lock = "noctalia msg session lock";
    };
  };
}
