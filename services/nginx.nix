{ config, pkgs, ... }:

{
  services.nginx.enable = true;
  services.nginx.virtualHosts."asdrubalini.xyz" = {
    # addSSL = true;
    # enableACME = true;
    # root = "/var/www/myhost.org";
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
