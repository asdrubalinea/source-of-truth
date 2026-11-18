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
  # app lets go. Whatever the cause, five silent minutes make the exporter exit
  # and Restart=always bring it back with a fresh monitor.
  systemd.services.govee-exporter = {
    description = "Publish Govee H5075 readings for the node-exporter textfile collector";
    # Started by the adapter's own device unit too, so it comes back with it.
    wantedBy = ["multi-user.target" "sys-subsystem-bluetooth-devices-hci0.device"];
    after = ["bluetooth.service" "sys-subsystem-bluetooth-devices-hci0.device"];
    requires = ["bluetooth.service"];
    # A bluetoothd restart drops the advertisement monitor without telling the
    # client, which would leave the exporter listening to nothing.
    partOf = ["bluetooth.service"];
    # So does the adapter leaving: the USB dongle drops off the bus while win11
    # holds the controller, and on 2026-11-14 the exporter came back from that
    # deaf, hearing only what other programs' active scans happened to turn up.
    bindsTo = ["sys-subsystem-bluetooth-devices-hci0.device"];
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
