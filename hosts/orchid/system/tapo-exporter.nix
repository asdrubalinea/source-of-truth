{pkgs, ...}: let
  # The Tapo P110 at the wall. Give it a DHCP reservation on the router: the
  # sandbox below only lets the exporter reach this one address.
  plug = "192.168.1.37";
  credentials = "/persist/secrets/tapo/credentials";
  python = pkgs.python3.withPackages (ps: [ps.python-kasa]);
in {
  # Wall power on Grafana. tapo-exporter.py logs into the plug over the LAN
  # (KLAP, the Tapo account's email + password — the plug checks them locally,
  # no cloud round trip) every 5 s and rewrites tapo.prom in the node-exporter
  # textfile directory that services/grafana/default.nix sets up, so the series
  # ride the existing `node` scrape and the orchid dashboard's "Wall Power" row
  # reads them. Same shape as strata-exporter.nix, root for the same reason.
  #
  # The credentials never enter the store: put the email on line 1 and the
  # password on line 2 of ${credentials} (root, 0600), then
  # `systemctl restart tapo-exporter`. Until that file exists the unit is
  # skipped rather than restart-looping.
  systemd.services.tapo-exporter = {
    description = "Publish the Tapo P110's power for the node-exporter textfile collector";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
    unitConfig.ConditionPathExists = credentials;
    serviceConfig = {
      ExecStart = "${python}/bin/python3 ${./tapo-exporter.py} --host ${plug} --credentials %d/tapo --dir /var/lib/node-exporter-textfile";
      LoadCredential = ["tapo:${credentials}"];
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
      IPAddressAllow = [plug];
      IPAddressDeny = ["any"];
    };
  };

  systemd.tmpfiles.rules = [
    "d /persist/secrets/tapo 0700 root root -"
  ];
}
