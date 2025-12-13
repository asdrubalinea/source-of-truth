{ ... }:
{
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
    ./system/virtualization.nix

    # User accounts
    ./users/irene.nix

    # Shared services
    ../../services/thermal-logger.nix

    # Shared hardware modules
    ../../hardware/bluetooth.nix
    ../../hardware/audio.nix
    ../../hardware/framework.nix

    # System modules
    # ../../modules/secure-boot.nix
    ../../modules/nix.nix

    # Services
    # ../../services/btrfs-snapshots.nix
    ../../services/borg-home-backup.nix
    ../../services/nix-cleanup.nix
    ../../services/grafana/default.nix
    # ../../services/syncthing.nix

    # Desktop environment
    # ../../rices/estradiol/system.nix
    # ../../desktop/gnome.nix
    ../../rices/niri/system.nix
  ];

  # System Version
  system.stateVersion = "24.11";
}
