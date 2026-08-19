{...}: {
  imports = [
    # Hardware
    ./hardware.nix

    # System configuration
    ./system/boot.nix
    ./system/localization.nix
    ./system/networking.nix
    ./system/persistence.nix
    ./system/environment.nix
    ./system/security.nix
    ./system/services.nix
    ./system/vaultwarden-export.nix
    ./system/virtualization.nix

    # User accounts
    ./users/irene.nix

    # Shared hardware modules
    ../../hardware/bluetooth.nix
    ../../hardware/zfs.nix
    ../../hardware/audio.nix

    # System modules
    ../../modules/nix.nix

    # Services
    ../../services/borg-backup.nix
    ../../services/caddy
    ../../services/syncthing.nix

    # Desktop environment
    ../../rices/estradiol/fonts.nix
  ];

  # `nh os switch` / `nh home switch` / `nh clean all` — replaces the old
  # config-apply / user-apply / system-clean wrappers. Sets NH_FLAKE so the
  # commands work from any directory.
  programs.nh = {
    enable = true;
    flake = "/persist/source-of-truth";

    # Weekly GC across system + user + home-manager profiles (nix.gc only ever
    # pruned the system one). See hosts/tempest/default.nix for the long note.
    clean = {
      enable = true;
      extraArgs = "--keep 5 --keep-since 7d";
    };
  };

  # Mutually exclusive with programs.nh.clean; modules/nix.nix defaults it on.
  nix.gc.automatic = false;

  # System Version
  system.stateVersion = "23.05";
}
