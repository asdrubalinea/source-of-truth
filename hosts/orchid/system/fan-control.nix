{pkgs, ...}: {
  # Case fans driven by the DIMM temperature (fan-control.py has the story:
  # the BIOS curves follow the CPU, and under a memory-bound load the DDR5
  # modules reached 72 °C and started miscomparing on 2026-10-09; the same
  # kit was clean for four hours at 55 °C once the fans ran). The controller
  # is the Nuvoton NCT6799 on the B650 Pro RS; nct6775 found it without
  # acpi_enforce_resources=lax.
  boot.kernelModules = ["nct6775"];

  systemd.services.fan-control = {
    description = "Case fans from the DIMM temperature (NCT6799 via hwmon)";
    wantedBy = ["multi-user.target"];
    after = ["systemd-modules-load.service"];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./fan-control.py}";
      # SIGTERM makes the script hand the headers back to the BIOS curve.
      KillSignal = "SIGTERM";
      Restart = "always";
      RestartSec = 5;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateNetwork = true;
      NoNewPrivileges = true;
      # It writes /sys/class/hwmon/*/pwm*, so no ProtectKernelTunables.
    };
  };
}
