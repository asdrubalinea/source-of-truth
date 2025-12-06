{ ... }:
{
  services = {
    openssh.enable = true;

    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };

    monitoring = {
      enable = false;
      powerEfficient = true;
    };
  };
}
