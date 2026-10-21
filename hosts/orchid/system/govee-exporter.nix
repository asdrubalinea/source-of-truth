{pkgs, ...}: let
  python = pkgs.python3.withPackages (ps: [ps.bleak]);
in {
  # Room temperature and humidity on Grafana, from a Govee H5075 thermometer.
  # The H5075 broadcasts its reading over BLE every couple of seconds;
  # govee-exporter.py listens passively through bluetoothd (no pairing, no Govee
  # account, no cloud) and rewrites govee.prom in the node-exporter textfile
  # directory that services/grafana/default.nix sets up, so the series ride the
  # existing `node` scrape and the orchid dashboard's "Room" row reads them.
  # Same shape as tapo-exporter.nix; root because bluetoothd's D-Bus policy and
  # the root-owned textfile directory both expect it.
  #
  # Every H5075 in range is published, labelled by MAC and advertised name, so a
  # second thermometer needs no change here. While the Govee phone app holds a
  # connection the H5075 stops advertising, and the readings go stale until the
  # app lets go.
  systemd.services.govee-exporter = {
    description = "Publish Govee H5075 readings for the node-exporter textfile collector";
    wantedBy = ["multi-user.target"];
    after = ["bluetooth.service"];
    requires = ["bluetooth.service"];
    # A bluetoothd restart drops the advertisement monitor without telling the
    # client, which would leave the exporter listening to nothing.
    partOf = ["bluetooth.service"];
    serviceConfig = {
      ExecStart = "${python}/bin/python3 ${./govee-exporter.py} --dir /var/lib/node-exporter-textfile";
      Restart = "always";
      RestartSec = 10;
      ProtectSystem = "strict";
      ReadWritePaths = ["/var/lib/node-exporter-textfile"];
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateNetwork = true; # only the system bus socket is needed
      NoNewPrivileges = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = ["AF_UNIX"];
    };
  };
}
