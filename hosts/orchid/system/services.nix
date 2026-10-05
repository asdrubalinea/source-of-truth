{inputs, ...}: let
  system = "x86_64-linux";
  getNixosModule = flake:
    if flake ? nixosModules && flake.nixosModules ? default
    then flake.nixosModules.default
    else flake.nixosModules.${system}.default;
in {

  # The Hetzner storage box that backs every borg job below. Declared here so a
  # fresh install can run its first backup without an interactive host-key
  # prompt — /home/irene/.ssh/known_hosts is empty on a new pool.
  programs.ssh.knownHosts = {
    "[u518612.your-storagebox.de]:23" = {
      hostNames = ["[u518612.your-storagebox.de]:23"];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
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

  # earlyoom: SIGTERM the biggest memory hog before the box livelocks. Same
  # thresholds as tempest (hosts/tempest/system/services.nix has the reasoning,
  # and system/memory.nix there the MemAvailable trap): decide on RAM alone, at
  # <5% available — the 16 GiB swap LV is overflow, not a cushion to thrash into.
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 100;
  };

  # The G502's thumb button → super+e, as on tempest. 046d:c547 is the Lightspeed
  # receiver, so this follows the receiver to whichever machine it is plugged in.
  services.keyd = {
    enable = true;
    keyboards.g502 = {
      ids = ["046d:c547"];
      settings.main.C-up = "macro(super+e)";
    };
  };

  # Mask Speech Dispatcher: GTK/Chromium apps pull in speechd via AT-SPI, and its
  # socket-activated user units spawn the daemon plus every synthesizer in each
  # session. Nothing here uses screen-reader TTS. See the tempest note.
  systemd.user.services.speech-dispatcher.enable = false;
  systemd.user.sockets.speech-dispatcher.enable = false;

  # nix.gc.automatic, which hosts/orchid/default.nix already sets alongside
  # programs.nh.clean.
}
