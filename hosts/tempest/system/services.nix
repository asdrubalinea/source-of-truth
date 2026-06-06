{ pkgs, ... }:
{
  programs.nix-ld.enable = true;

  programs.ssh.knownHosts = {
    "[u518612.your-storagebox.de]:23" = {
      hostNames = [ "[u518612.your-storagebox.de]:23" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
    };
  };

  services = {
    # earlyoom: SIGTERM the biggest memory hog before the box livelocks under
    # memory pressure — the usual cause of the hard freezes that force a power
    # cut (and thus unclean-shutdown lost writes). Decide on RAM alone: the 40G
    # swap is sized for hibernation (>= RAM, see disks/tempest.nix), not a
    # runtime cushion to thrash into, so don't wait for it to fill. SIGTERM at
    # <5% available RAM, SIGKILL at half that. Raise freeMemThreshold if it ever
    # fires too eagerly.
    earlyoom = {
      enable = true;
      freeMemThreshold = 5;
      freeSwapThreshold = 100;
    };

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

    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "prohibit-password";
        KbdInteractiveAuthentication = false;
      };
    };

    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };

    monitoring = {
      enable = true;
      powerEfficient = false;
    };

    flatpak.enable = true;

    framework-control = {
      enable = true;
      # The ozturkkl/framework-control flake's nixpkgs fork pins a stale src
      # hash for the v0.5.2 GitHub tag (overrideAttrs of src didn't propagate
      # into the cargo-vendor FOD), so build the package locally with the
      # currently-served tag hash instead.
      package = pkgs.callPackage ../../../packages/framework-control.nix { };
    };

    vaultwarden = {
      enable = true;
      dbBackend = "sqlite";
      backupDir = "/persist/vaultwarden";
      config = {
        DOMAIN = "https://bitwarden.irene.foo";
        SIGNUPS_ALLOWED = false;
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;
        WEBSOCKET_ADDRESS = "127.0.0.1";
        ENABLE_WEBSOCKET = true;
        SENDS_ALLOWED = true;
        ROCKET_LOG = "critical";
      };
    };
  };

  services.keyd = {
    enable = true;
    keyboards.g502 = {
      ids = [ "046d:c547" ];
      settings.main.C-up = "macro(super+e)";
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
