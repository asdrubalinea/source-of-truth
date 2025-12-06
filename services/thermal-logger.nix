{ pkgs, ... }:

let
  thermalLogger = pkgs.writeShellApplication {
    name = "thermal-logger";
    runtimeInputs = [ pkgs.coreutils pkgs.gawk ];
    text = builtins.readFile ../scripts/thermal-logger.sh;
  };
  logPath = "/var/log/thermal-logger.csv";
in
{
  systemd.services.thermal-logger = {
    description = "Thermal telemetry logger";
    wantedBy = [ "multi-user.target" ];
    after = [ "syslog.target" ];
    serviceConfig = {
      ExecStart = "${thermalLogger}/bin/thermal-logger";
      Restart = "always";
      RestartSec = 5;
      StandardOutput = "append:${logPath}";
      StandardError = "journal";
      User = "root";
    };
  };

  systemd.tmpfiles.rules = [
    "f ${logPath} 0644 root root -"
  ];
}
