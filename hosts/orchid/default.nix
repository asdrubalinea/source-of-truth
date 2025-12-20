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

  # System Version
  system.stateVersion = "23.05";
}
