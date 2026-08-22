{...}: {
  # Host-specific state only. The tmpfs-root core — /persist mounted early, the
  # machine-id + SSH host keys, /var/log, /home/irene's ownership, the nix build
  # dir redirect and the soft-reboot fixup — is modules/impermanence-root.nix,
  # shared with orchid. /nix, /persist and /var/lib/sbctl are owned by disko
  # (disks/tempest.nix).
  environment.persistence."/persist".directories = [
    # Network configuration
    "/etc/NetworkManager/system-connections"

    "/var/lib/bluetooth"

    # System-wide flatpak installs (services.flatpak / nix-flatpak). Without
    # this the repo + apps live on tmpfs root and are wiped every reboot, so
    # nix-flatpak re-adds the remote and re-downloads declared packages from
    # scratch on each boot (and any manual installs are simply lost).
    "/var/lib/flatpak"
    "/var/lib/tailscale"
    "/var/lib/grafana"
    "/var/lib/prometheus2"
    "/var/lib/prometheus-node-exporter"

    # The read-only vault mirror's store (services/vaultwarden-mirror.nix).
    "/var/lib/vaultwarden"
  ];

  # programs.fuse.userAllowOther = true;
}
