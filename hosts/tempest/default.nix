{ ... }:
{
  imports = [
    # Hardware
    ./hardware.nix

    # System configuration
    ./system/boot.nix
    ./system/zfs.nix
    ./system/localization.nix
    ./system/networking.nix
    ./system/persistence.nix
    ./system/environment.nix
    ./system/security.nix
    ./system/services.nix
    ./system/vaultwarden-sync.nix
    ./system/virtualization.nix
    ./system/firejail.nix

    # User accounts
    ./users/irene.nix

    # Shared services
    # ../../services/thermal-logger.nix

    # Shared hardware modules
    ../../hardware/bluetooth.nix
    ../../hardware/audio.nix
    ../../hardware/framework.nix

    # System modules
    # secure-boot.nix (lanzaboote) is intentionally left disabled for the FIRST
    # install: it mkForce-disables systemd-boot and signs UKIs against keys in
    # /var/lib/sbctl, which don't exist yet on a fresh disk. Boot once with
    # systemd-boot (system/boot.nix), run `sbctl create-keys`, then enable this
    # and enroll keys.
    # ../../modules/secure-boot.nix
    ../../modules/nix.nix

    # Services
    # ../../services/btrfs-snapshots.nix
    ../../services/borg-backup.nix
    ../../services/nix-cleanup.nix
    ../../services/redshift.nix
    ../../services/grafana/default.nix
    # ../../services/syncthing.nix

    # Desktop environment
    # ../../rices/estradiol/system.nix
    # ../../desktop/gnome.nix
    ../../rices/niri/system.nix
  ];

  programs.nh = {
    enable = true;
    flake = "/persist/source-of-truth";
  };

  # System Version
  system.stateVersion = "24.11";
}
