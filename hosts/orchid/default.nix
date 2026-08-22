{
  inputs,
  lib,
  virtual ? false,
  ...
}: {
  imports =
    [
      # Hardware
      ./hardware.nix

      # System configuration
      ./system/boot.nix
      ./system/localization.nix
      ./system/networking.nix
      ./system/environment.nix
      ./system/services.nix
      ./system/vaultwarden-export.nix
      ./system/virtualization.nix

      # User accounts
      ./users/irene.nix

      # Shared hardware modules
      ../../hardware/bluetooth.nix
      ../../hardware/audio.nix

      # System modules
      ../../modules/nix.nix
      ../../modules/security.nix
      ../../modules/zfs-on-luks.nix
      ../../modules/impermanence-root.nix

      # Services
      ../../services/borg-backup.nix
      ../../services/caddy
      ../../services/syncthing.nix

      # --- Filesystem + boot layer: same shape as tempest (GPT + LUKS + LVM +
      #     swap + ZFS datasets + tmpfs root + impermanence). See disks/orchid.nix
      #     and docs/orchid-install.md. ---
      inputs.disko.nixosModules.disko
      inputs.impermanence.nixosModules.impermanence
      ../../disks/orchid.nix
      ./system/zfs.nix
      ./system/persistence.nix

      # No desktop: this host runs headless for now, so no rice is imported and
      # no compositor/greeter is installed. rices/estradiol (hyprland) is still
      # in the tree, imported by nothing — wire it back in here and in
      # homes/orchid.nix when a WM is wanted again.
    ]
    ++ lib.optionals virtual [
      # --- QEMU clone only: guest sizing, home-manager as a NixOS module, and
      #     mkForce-off for the units that need credentials this VM has no
      #     business holding. ---
      ./vm.nix
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

  # Bumped from 23.05 for the reinstall: the pool is created fresh, so nothing
  # depends on the old value's state-dir choices. One consequence to know about:
  # vaultwarden's data dir is /var/lib/vaultwarden at >= 24.11, where 23.05 used
  # /var/lib/bitwarden_rs — restore the vault backup into the former. See
  # docs/orchid-install.md.
  system.stateVersion = "25.11";
}
