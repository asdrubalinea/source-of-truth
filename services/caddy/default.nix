{ hostname ? null, pkgs, ... }:
let
  hostConfigFile = if hostname != null then ./. + "/${hostname}.Caddyfile" else null;
  config =
    if hostConfigFile != null && builtins.pathExists hostConfigFile then
      builtins.readFile hostConfigFile
    else
      builtins.readFile ./Caddyfile;
  environmentFile = if hostname == "hydra" then "/var/lib/caddy/env" else "/persist/caddy/env";
in
{
  services.caddy = {
    enable = true;

    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.2" ];
      hash = "sha256-Gb1nC5fZfj7IodQmKmEPGygIHNYhKWV1L0JJiqnVtbs=";
    };

    globalConfig = ''
      debug
      email acme@irene.foo
      grace_period 60s
    '';

    extraConfig = config;
  };

  systemd.services.caddy.serviceConfig.EnvironmentFile = [ environmentFile ];
}
