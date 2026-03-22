{ ... }:
{
  networking = {
    hostName = "hydra";
    hostId = "31c78e4a";
    networkmanager.enable = false;
    useDHCP = true;
    enableIPv6 = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
      checkReversePath = "loose";
    };
  };
}
