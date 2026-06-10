{ ... }:
{
  networking = {
    hostName = "zephyr";
    networkmanager.enable = false;

    # Wired Ethernet, DHCP. No static IP — discovery is via mDNS (see avahi in
    # system/services.nix): `ssh irene@zephyr.local`.
    useDHCP = true;
    enableIPv6 = true;

    firewall = {
      enable = true;

      # SSH (22) is opened by services.openssh.openFirewall (default true), so
      # the very first `tailscale up` is reachable over the LAN. Everything else
      # stays closed here and is opened per-interface on tailscale0 as services
      # land, mirroring hydra. Optionally tighten SSH to tailscale0-only once the
      # tailnet is joined.
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
      checkReversePath = "loose";
    };
  };
}
