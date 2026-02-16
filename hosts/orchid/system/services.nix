{ inputs, ... }:
let
  system = "x86_64-linux";
  getNixosModule = flake:
    if flake ? nixosModules && flake.nixosModules ? default then
      flake.nixosModules.default
    else
      flake.nixosModules.${system}.default;
in
{
  imports = [
    (getNixosModule inputs.diapee-bot)
    (getNixosModule inputs.tribunale-scrape)
  ];

  nix.gc = {
    automatic = false;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  services.flatpak.enable = true;

  services.borg-backup = {
    enable = true;
    jobs = {
      vault = {
        user = "irene";
        repo = "ssh://u518612@u518612.your-storagebox.de:23/./backups/orchid-vault";
        ssh_key_file = "/home/irene/.ssh/id_ed25519";
        password_file = "/persist/borg-vault-backup/passphrase";
        paths = [ "/persist/Vault" ];
      };

      home-irene = {
        user = "irene";
        repo = "ssh://u518612@u518612.your-storagebox.de:23/./backups/orchid-home-irene";
        ssh_key_file = "/home/irene/.ssh/id_ed25519";
        password_file = "/persist/borg-home-backup/passphrase";
        paths = [ "/home/irene" ];
      };
    };
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    permitCertUid = "caddy";
    extraSetFlags = [ "--advertise-exit-node" ];
  };

  # services.ollama = {
  #   enable = false;
  #   host = "0.0.0.0";
  #   acceleration = "rocm";
  #   rocmOverrideGfx = "10.3.1";
  #   openFirewall = true;
  # };

  services.openssh.enable = true;

  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    backupDir = "/persist/vaultwarden";
    config = {
      DOMAIN = "https://bitwarden.irene.foo";
      SIGNUPS_ALLOWED = true;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      ENABLE_WEBSOCKET = true;
      SENDS_ALLOWED = true;
      ROCKET_LOG = "critical";
    };
  };

  services.github-runners = {
    leksi = {
      enable = false;
      name = "leksi";
      tokenFile = "/persist/secrets/github-runners/leksi";
      url = "https://github.com/asdrubalinea/leksi";
    };
  };

  # services.glance = {
  #   enable = true;
  #   openFirewall = true;
  #   settings.server.port = 5678;
  # };

  services.ncps = {
    enable = true;
    server = {
      addr = ":8501";
    };

    logLevel = "trace";

    cache = {
      maxSize = "500G";
      hostName = "orchid.boreal-city.ts";
      upstream = {
        urls = [
          "https://cache.nixos.org/"
          "https://hyprland.cachix.org"
          "https://cosmic.cachix.org/"
        ];
        publicKeys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
          "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
        ];
      };
    };
  };

  services.diapee-bot = {
    enable = true;

    web = {
      enable = true;
      port = 3000;
    };

    environmentFile = "/persist/diapee-bot/env";
    dataDir = "/persist/diapee-bot";

    extraEnvironment = {
      RUST_LOG = "info,diapee_bot=debug";
      DIAPEEBOT_MODEL = "google/gemini-2.5-pro";
      DIAPEEBOT_PRONOUNS = "she/her";
    };
  };

  services.tribunale-scrape = {
    enable = false;
    environmentFile = "/persist/tribunale-scrape/env";
    dataDir = "/persist/tribunale-scrape";
    extraEnvironment = {
      RUST_LOG = "info";
    };
  };

  services.gitea = {
    enable = true;
    stateDir = "/persist/gitea";

    settings.server = {
      DOMAIN = "gitea.irene.foo";
      ROOT_URL = "https://gitea.irene.foo/";
      HTTP_ADDR = "127.0.0.1";
      HTTP_PORT = 4001;
    };
  };
}
