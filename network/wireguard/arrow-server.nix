{ config, lib, pkgs, ... }:

let
  networkIp = "10.0.64.1/24";
  networkSubnet = "10.0.64.0/24";
  interface = "ens3";
  listenPort = 51820;
in
{
  # Enable NAT
  networking.nat = {
    enable = true;
    externalInterface = "eth0";
    internalInterfaces = [ "wg0" ];
  };

  # Allow wireguard to pass through firewall
  networking.firewall = {
    allowedUDPPorts = [ listenPort ];
  };

  networking.wireguard.interfaces = {
    wg0 = {
      # Determines the IP address and subnet of the server's end of the tunnel interface.
      ips = [ networkIp ];

      # The port that WireGuard listens to. Must be accessible by the client.
      # inherit listenPort;
      listenPort = listenPort;

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
          publicKey = "HydrAcOg1rk1BL/xjlEkVwxjOsps1crFKMnvmFyNNDU=";
          allowedIPs = [ "10.0.64.2/32" ];
        }

        {
          publicKey = "IyBZU6xWEXLRIulxyfcXmpAKuNXH+6ydeqhH1iOHhgk=";
          allowedIPs = [ "10.0.64.3/32" ];
        }

        {
          publicKey = "iPad9SmsHPzxLOyEEAqJaZOdhXN0+6L4xkfzkLcl8k0=";
          allowedIPs = [ "10.0.64.4/32" ];
        }
      ];

    };
  };
}
