{ pkgs, inputs, ... }:
{
  imports = [
    inputs.nix-flatpak.nixosModules.nix-flatpak
    inputs.auxologico-check.nixosModules.default
  ];

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

    ollama = {
      enable = false;
      host = "127.0.0.1";
      # acceleration = "rocm";
      package = pkgs.ollama-rocm;
      # rocmOverrideGfx = "10.3.1";
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

    flatpak = {
      enable = true;
      remotes = [
        {
          name = "flathub";
          location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        }
      ];
      packages = [
        "io.github.streetpea.Chiaki4deck"
      ];
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

  # Appointment monitor: polls the auxologico portal in continuous --watch mode
  # (default) and notifies on new slots from startDate onward. The module creates
  # the auxologico-check user/group and a tmpfiles rule for dataDir. dataDir lives
  # under /persist (tempest's root FS is tmpfs; only /persist survives reboots).
  # environmentFile holds PHP_SESSION_ID + BEARER_TOKEN — created out-of-band, not
  # in the repo (see .env.example upstream); the unit fails to start until it exists.
  services.auxologico-check = {
    enable = true;
    startDate = "01/07/2026";
    environmentFile = "/persist/auxologico-check/env";
    dataDir = "/persist/auxologico-check";
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

  # Speech Dispatcher (text-to-speech): the `speechd` package — dragged in by
  # GTK/Chromium apps via the AT-SPI accessibility bus — ships a socket-activated
  # user service. The enabled `speech-dispatcher.socket` auto-spawns the
  # `speech-dispatcher` daemon and its `sd_*` synthesizer modules (espeak-ng,
  # festival, pico, …) in every session. Nothing here uses screen-reader TTS, so
  # mask both user units: `enable = false` symlinks them to /dev/null, which
  # overrides the package units and stops the socket from ever activating.
  systemd.user.services.speech-dispatcher.enable = false;
  systemd.user.sockets.speech-dispatcher.enable = false;
}
