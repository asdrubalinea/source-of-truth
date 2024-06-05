{ config, pkgs, ... }:

{
  services = {
    syncthing = {
      enable = true;
      user = "irene";
      guiAddress = "0.0.0.0:8384";

      dataDir = "/home/irene/";
      configDir = "/persist/syncthing-config/";
    };
  };
}
