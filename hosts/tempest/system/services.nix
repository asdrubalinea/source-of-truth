{ ... }:
{
  programs.nix-ld.enable = true;
  services = {
    borg-backup = {
      enable = true;
      jobs.home-irene = {
        user = "irene";
        repo = "ssh://u518612@u518612.your-storagebox.de:23/./backups/tempest-home-irene";
        ssh_key_file = "/home/irene/.ssh/id_ed25519";
        password_file = "/persist/borg-home-backup/passphrase";
        paths = [ "/home/irene" ];
      };
    };

    openssh.enable = true;

    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };

    monitoring = {
      enable = false;
      powerEfficient = true;
    };

    flatpak.enable = true;

    vaultwarden = {
      enable = true;
      dbBackend = "sqlite";
      backupDir = "/persist/vaultwarden";
      config = {
        DOMAIN = "https://bitwarden.irene.foo";
        SIGNUPS_ALLOWED = true;
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;
        WEBSOCKET_ADDRESS = "127.0.0.1";
        ENABLE_WEBSOCKET = true;
        SENDS_ALLOWED = true;
        ROCKET_LOG = "critical";
      };
    };
  };

  services.caddy = {
    enable = true;
    extraConfig = ''
      https://localhost {
        bind 127.0.0.1 ::1
        tls internal

        reverse_proxy /notifications/hub* 127.0.0.1:3012
        reverse_proxy 127.0.0.1:8222
      }
    '';
  };
}
