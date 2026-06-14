{ inputs, lib, virtual ? false, ... }:
{
  imports = [
    # --- Portable config: shared by the real laptop AND the VM ---

    # System configuration
    ./system/localization.nix
    ./system/networking.nix
    ./system/environment.nix
    ./system/security.nix
    ./system/services.nix
    ./system/backup-notify.nix
    ./system/session.nix
    ./system/vaultwarden-sync.nix
    ./system/virtualization.nix
    ./system/firejail.nix

    # User accounts
    ./users/irene.nix

    # Shared hardware modules
    ../../hardware/bluetooth.nix
    ../../hardware/audio.nix

    # System modules
    ../../modules/nix.nix

    # Services
    ../../services/borg-backup.nix
    ../../services/nix-cleanup.nix
    ../../services/redshift.nix
    ../../services/grafana/default.nix

    # Desktop environment
    ../../rices/niri/system.nix

    # --- Filesystem + boot layer: shared so the VM reproduces tempest's EXACT
    #     on-disk layout (GPT + LUKS + LVM + swap + ZFS datasets + tmpfs root +
    #     impermanence). The `tempest-vm` build uses disko's `vmWithDisko`, which
    #     formats a virtual disk straight from the disko.devices spec below, so
    #     the VM mounts the same datasets and exercises the same impermanence
    #     bind-mounts. boot.nix's CachyOS LTS kernel is kept in both because the
    #     out-of-tree ZFS build needs it (see system/zfs.nix). ---
    inputs.disko.nixosModules.disko
    inputs.impermanence.nixosModules.impermanence
    ../../disks/tempest.nix
    ./system/boot.nix
    ./system/zfs.nix
    ./system/persistence.nix
  ]
  ++ lib.optionals (!virtual) [
    # --- Physical Framework laptop only ---
    # Hardware drivers, microcode, secure-boot plumbing and the external-disk
    # backup are meaningless (or actively error) inside a VM, so they are simply
    # not evaluated when virtual = true.
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.ucodenix.nixosModules.default

    ./hardware.nix
    ../../hardware/framework.nix
    ./system/backup-external.nix

    # secure-boot.nix (lanzaboote) is intentionally left disabled for the FIRST
    # install: it mkForce-disables systemd-boot and signs UKIs against keys in
    # /var/lib/sbctl, which don't exist yet on a fresh disk. Boot once with
    # systemd-boot (system/boot.nix), run `sbctl create-keys`, then enable this
    # and enroll keys.
    # ../../modules/secure-boot.nix
  ]
  ++ lib.optionals virtual [
    # --- VM-only layer: home-manager, guest sizing, declarative repo seed ---
    ./vm.nix
  ];

  programs.nh = {
    enable = true;
    flake = "/persist/source-of-truth";
  };

  # System Version
  system.stateVersion = "24.11";
}
