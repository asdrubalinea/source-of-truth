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
      interfaces.tailscale0.allowedTCPPorts = [
        80
        443
      ];
      checkReversePath = "loose";
    };
  };
}
