{pkgs, ...}: {
  # Strata's tokens/s on Grafana. The LLM server (/persist/strata, the
  # `strata-trial` unit inside the `strata` distrobox; not managed by this tree)
  # answers GET /metrics with JSON. strata-exporter.py polls it every 5 s and
  # rewrites strata.prom in the node-exporter textfile directory that
  # services/grafana/default.nix sets up, so the series ride the existing
  # `node` scrape and the orchid dashboard's "Strata" row reads them.
  #
  # Runs as root only because the textfile directory is root-owned 0755 (the
  # inotify collector in services/grafana has the same shape); the rest of the
  # sandbox is shut. It talks to 127.0.0.1:8080 and nothing else.
  systemd.services.strata-exporter = {
    description = "Publish Strata's /metrics for the node-exporter textfile collector";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./strata-exporter.py} --dir /var/lib/node-exporter-textfile --url http://127.0.0.1:8080/metrics";
      Restart = "always";
      RestartSec = 10;
      ProtectSystem = "strict";
      ReadWritePaths = ["/var/lib/node-exporter-textfile"];
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
      IPAddressAllow = ["localhost"];
      IPAddressDeny = ["any"];
    };
  };

  # node-exporter's rapl collector gives the CPU package power the dashboard's
  # "CPU package power" panel wants, but the kernel makes energy_uj root-only
  # and the exporter runs as a dynamic user, so the series was empty. Reading
  # the counter is harmless; make it world-readable at boot.
  systemd.tmpfiles.rules = [
    "z /sys/class/powercap/intel-rapl:0/energy_uj 0444 - - -"
    "z /sys/class/powercap/intel-rapl:0:0/energy_uj 0444 - - -"
  ];
}
