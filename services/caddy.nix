{ ... }:

{
  services.caddy = {
    enable = false;
    virtualHosts."caddy.asdrubalini.xyz".extraConfig = ''
      bind 100.97.93.53

      tls {
        dns cloudflare {env.CF_API_TOKEN}
      }

      respond "Hello, world!"
    '';
  };
}
