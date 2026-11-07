{modulesPath, ...}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./hardware.nix

    ./system/boot.nix
    ./system/localization.nix
    ./system/networking.nix
    ./system/security.nix
    ./system/services.nix
    ../../services/vaultwarden-mirror.nix
    ./system/environment.nix

    ./users/irene.nix

    ../../modules/nix.nix
    ../../modules/orchid-builder.nix # 4-vCPU guest; orchid does the compiling
    ../../modules/security.nix
    ../../services/caddy
  ];

  # `nh os switch` / `nh clean all` — replaces the old config-apply /
  # system-clear wrappers. Sets NH_FLAKE so both work from any directory.
  programs.nh = {
    enable = true;
    flake = "/home/irene/source-of-truth";

    # Weekly GC across system + user profiles. See hosts/tempest/default.nix.
    clean = {
      enable = true;
      extraArgs = "--keep 5 --keep-since 7d";
    };
  };

  # tempest as a second builder while orchid is offline. Appends to
  # modules/orchid-builder.nix's list and reuses its key (tempest authorizes
  # `irene@orchid` too); the lower speedFactor keeps orchid first once it's back.
  nix.buildMachines = [
    {
      hostName = "tempest";
      sshUser = "irene";
      sshKey = "/home/irene/.ssh/id_ed25519";
      protocol = "ssh-ng";
      system = "x86_64-linux";
      maxJobs = 4;
      speedFactor = 2;
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    }
  ];
  programs.ssh.knownHosts.tempest = {
    hostNames = ["tempest" "tempest.boreal-city.ts.net"];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPB7r8eXk0jHDOYGC+Gm7Mu9W50H89VwuIJ4h/C8bP7L";
  };

  # Mutually exclusive with programs.nh.clean; modules/nix.nix defaults it on.
  nix.gc.automatic = false;

  system.stateVersion = "24.11";
}
