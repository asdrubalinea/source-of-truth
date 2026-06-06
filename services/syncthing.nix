{ ... }:

{
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
}
