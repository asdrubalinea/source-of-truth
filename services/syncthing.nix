{...}: {
  services = {
    syncthing = {
      enable = true;
      user = "irene";
      # Bind the (unauthenticated-by-default) GUI/API to loopback only; reach it
      # via an SSH tunnel rather than exposing it on the LAN/tailnet.
      guiAddress = "127.0.0.1:8384";

      dataDir = "/home/irene/";
      configDir = "/persist/syncthing-config/";
    };
  };

  # configDir is outside /var/lib, so the module's StateDirectory does not cover
  # it — and on a freshly formatted pool /persist is root:root 0755, so syncthing
  # (running as irene) cannot create it. The unit then fails five times in two
  # seconds and start-limit-hits: "Failed to ensure directory exists (error=
  # \"mkdir /persist/syncthing-config: permission denied\")". Only shows up on the
  # FIRST boot after an install, which is exactly why it went unnoticed — found by
  # booting orchid-vm on a fresh pool. 0700 because this directory holds the
  # device's private key and cert.
  systemd.tmpfiles.rules = ["d /persist/syncthing-config 0700 irene users -"];
}
