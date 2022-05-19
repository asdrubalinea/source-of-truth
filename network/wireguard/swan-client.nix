{ config, lib, pkgs, ... }:

let
  networkIp = "10.0.73.2/24";
in {
  networking.firewall = {
    allowedUDPPorts = [ 51820 ];
  };

  networking.wireguard.interfaces = {
    wg0 = {
      # Determines the IP address and subnet of the client's end of the tunnel interface.
      ips = [ networkIp ];
      listenPort = 51820;

      # Path to the private key file.
      privateKeyFile = "/persist/wireguard/private";

      peers = [
        # For a client configuration, one peer entry for the server will suffice.

        {
          # Public key of the server.
          publicKey = "8I433B1dtVxm2lOy2QjcedGMoK7FabJFAUTiCh0Mg1U=";

          # Forward all the traffic via VPN.
          allowedIPs = [ "0.0.0.0/0" ];

          # Set this to the server IP and port.
          endpoint = "arrow:51820";

          # Send keepalives every 25 seconds. Important to keep NAT tables alive.
          persistentKeepalive = 25;
        }
      ];
    };
  };
}
