{ pkgs, inputs, ... }:
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
{
  home.packages = [ pkgs.swaylock-effects ];

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
    ];
    events = {
      before-sleep = "${pkgs.systemd}/bin/loginctl lock-session";
      lock = "${pkgs.swaylock-effects}/bin/swaylock -f";
    };
  };
}
