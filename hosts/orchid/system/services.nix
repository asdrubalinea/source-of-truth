{inputs, ...}: let
  system = "x86_64-linux";
  getNixosModule = flake:
    if flake ? nixosModules && flake.nixosModules ? default
    then flake.nixosModules.default
    else flake.nixosModules.${system}.default;
in {
  imports = [
    (getNixosModule inputs.diapee-bot)
    (getNixosModule inputs.tribunale-scrape)
    (getNixosModule inputs.auxologico-check)
  ];

  # The Hetzner storage box that backs every borg job below. Declared here so a
  # fresh install can run its first backup without an interactive host-key
  # prompt — /home/irene/.ssh/known_hosts is empty on a new pool.
  programs.ssh.knownHosts = {
    "[u518612.your-storagebox.de]:23" = {
      hostNames = ["[u518612.your-storagebox.de]:23"];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
    };
  };

  services.borg-backup = {
    enable = true;
    jobs = {
      vault = {
        user = "irene";
        repo = "ssh://u518612@u518612.your-storagebox.de:23/./backups/orchid-vault";
        ssh_key_file = "/home/irene/.ssh/id_ed25519";
        password_file = "/persist/borg-vault-backup/passphrase";
        paths = ["/persist/Vault"];
      };

      home-irene = {
        user = "irene";
        repo = "ssh://u518612@u518612.your-storagebox.de:23/./backups/orchid-home-irene";
        ssh_key_file = "/home/irene/.ssh/id_ed25519";
        password_file = "/persist/borg-home-backup/passphrase";
        paths = ["/home/irene"];
      };
    };
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    permitCertUid = "caddy";
    extraSetFlags = ["--advertise-exit-node"];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      KbdInteractiveAuthentication = false;
    };
  };

  # The primary Vaultwarden. tempest and hydra run read-only mirrors of this one
  # (services/vaultwarden-mirror.nix), fed by system/vaultwarden-export.nix.
  # /var/lib/vaultwarden is bind-mounted from /persist (system/persistence.nix).
  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    backupDir = "/persist/vaultwarden";
    config = {
      DOMAIN = "https://bitwarden.irene.foo";
      SIGNUPS_ALLOWED = false; # account already enrolled; re-enable briefly to add users
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

  services.ncps = {
    enable = true;
    server = {
      addr = ":8501";
    };

    logLevel = "trace";

    cache = {
      maxSize = "500G";
      hostName = "orchid.boreal-city.ts";

      # The store lives on its own ZFS dataset with a 560G quota
      # (disks/orchid.nix), and maxSize is only enforced when the LRU cleaner
      # actually runs — with no schedule set it never does, so the cache grew
      # until something else broke. Nightly at 03:00.
      lru.schedule = "0 3 * * *";

      # NARs are downloaded here before being committed to the store. The
      # default is /tmp, which on this host is the tmpfs root — i.e. RAM. The
      # module creates the directory and grants the unit write access.
      tempPath = "/var/lib/ncps/tmp";

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

  services.auxologico-check = {
    enable = true;
    startDate = "20/02/2026";
    environmentFile = "/persist/auxologico-check/env";
    dataDir = "/persist/auxologico-check";
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

  # Dropped with the desktop: services.flatpak (nothing graphical to run) and
  # the commented-out services.ollama block (rocm, no GPU in this machine). The
  # local `nix.gc` block that used to live here is gone too — it re-declared
  # nix.gc.automatic, which hosts/orchid/default.nix already sets alongside
  # programs.nh.clean.
}
