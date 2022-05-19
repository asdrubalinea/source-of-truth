{ config, lib, pkgs, ... }:

let
  networkIp = "10.0.73.1/24";
  networkSubnet = "10.0.73.0/24";
  interface = "ens3";

in {
  # Enable NAT
  networking.nat = {
    enable = true;
    externalInterface = "eth0";
    internalInterfaces = [ "wg0" ];
  };

  # Allow wireguard to pass through firewall
  networking.firewall = {
    allowedUDPPorts = [ 51820 ];
  };

  networking.wireguard.interfaces = {
    wg0 = {
      # Determines the IP address and subnet of the server's end of the tunnel interface.
      ips = [ networkIp ];

      # The port that WireGuard listens to. Must be accessible by the client.
      listenPort = 51820;

      # This allows the wireguard server to route your traffic to the internet and hence be like a VPN
      # For this to work you have to set the dnsserver IP of your router (or dnsserver of choice) in your clients
      postSetup = ''
        ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s ${networkSubnet} -o ${interface} -j MASQUERADE
      '';

      # This undoes the above command
      postShutdown = ''
        ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s ${networkSubnet} -o ${interface} -j MASQUERADE
      '';

      # Path to the private key file.
      privateKeyFile = "/persist/wireguard/private";

      peers = [
        {
          publicKey = "SK7+J09aRkZQ703YExwacoZN/sVdG72Oyj/7RFIBb1E=";
          allowedIPs = [ "10.0.73.2/32" ];
        }
      ];

    };
  };
}
