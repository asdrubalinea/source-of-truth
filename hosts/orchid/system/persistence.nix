{...}: {
  # Host-specific state only; the tmpfs-root core is
  # modules/impermanence-root.nix, shared with tempest. /nix, /persist,
  # /var/lib/docker and /var/lib/ncps are owned by disko (disks/orchid.nix).
  #
  # Everything else stateful on this host already writes straight into /persist
  # by config (gitea, syncthing, diapee-bot, auxologico-check, the borg
  # passphrases, caddy's env file, the vaultwarden export) — these are the ones
  # that insist on /var/lib.
  environment.persistence."/persist".directories = [
    "/var/lib/bluetooth"
    "/var/lib/tailscale"

    # Vaultwarden's live store. orchid is the PRIMARY vault (tempest and hydra
    # run read-only mirrors of it via services/vaultwarden-mirror.nix), so
    # losing this is losing the vault.
    "/var/lib/vaultwarden"

    # Caddy's ACME account key and issued certificates. Without this every boot
    # re-requests certs and will hit Let's Encrypt rate limits.
    "/var/lib/caddy"

    "/var/lib/libvirt"
  ];
}
