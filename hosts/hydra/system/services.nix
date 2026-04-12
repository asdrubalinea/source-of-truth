{ ... }:
{
  systemd.services.vaultwarden = {
    serviceConfig = {
      Restart = "always";
      RestartSec = 5;
    };
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        KbdInteractiveAuthentication = false;
      };
    };

    tailscale = {
      enable = true;
      openFirewall = true;
      useRoutingFeatures = "server";
      permitCertUid = "caddy";
      extraSetFlags = [ "--advertise-exit-node" ];
    };

    vaultwarden = {
      enable = true;
      dbBackend = "sqlite";
      backupDir = "/var/backup/vaultwarden";
      config = {
        DOMAIN = "https://hydra.irene.foo";
        SIGNUPS_ALLOWED = true;
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;
        ENABLE_WEBSOCKET = true;
        SENDS_ALLOWED = true;
        ROCKET_LOG = "critical";
      };
    };
  };
}
