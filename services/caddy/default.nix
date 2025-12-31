{ pkgs, ... }:
let
  config = builtins.readFile ./Caddyfile;
in
{
  services.caddy = {
    enable = true;

    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.2" ];
      hash = "sha256-ea8PC/+SlPRdEVVF/I3c1CBprlVp1nrumKM5cMwJJ3U=";
    };

    globalConfig = ''
      debug
      email acme@irene.foo
      grace_period 60s
    '';

    extraConfig = config;
  };

  systemd.services.caddy.serviceConfig.EnvironmentFile = [ "/persist/caddy/env" ];
}
