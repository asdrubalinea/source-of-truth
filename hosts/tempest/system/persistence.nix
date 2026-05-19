{ lib, config, ... }:
let
  persistedFiles = map (
    f: if builtins.isString f then f else f.file
  ) config.environment.persistence."/persist".files;
in
{
  # Filesystem configuration for impermanence setup
  fileSystems = {
    # Root filesystem on tmpfs for impermanence
    "/" = {
      fsType = "tmpfs";
      options = [
        "defaults"
        "size=32G" # 32GB tmpfs for root
        "mode=755"
      ];
    };

    # Persistent storage subvolume
    "/persist" = {
      device = "/dev/pool/root";
      neededForBoot = true;
      fsType = "btrfs";
      options = [ "subvol=/@persist" ];
    };
  };

  # Impermanence configuration - what to persist across reboots
  environment.persistence."/persist" = {
    enable = true;
    hideMounts = true;

    # Directories that need to be persistent
    directories = [
      # System logs
      "/var/log"

      # System state
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/coredump"

      # Network configuration
      "/etc/NetworkManager/system-connections"

      # Services
      "/var/lib/tailscale"
      "/var/lib/sddm"
      "/var/lib/grafana"
      "/var/lib/prometheus2"
      "/var/lib/prometheus-node-exporter"
      "/var/lib/vaultwarden"
      "/var/lib/docker"

      "/home/irene"
    ];

    # Individual files that need persistence
    files = [
      "/etc/machine-id"

      # SSH host keys
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };

  # After `systemctl soft-reboot` the tmpfs root persists but impermanence's
  # bind mounts are torn down; systemd then regenerates /etc/machine-id and the
  # SSH host keys directly on tmpfs before activation runs, which trips
  # mount-file's "A file already exists" guard. Drop any persisted file that
  # isn't currently bind-mounted so persist-files can re-establish the mount.
  system.activationScripts.persist-files.text = lib.mkBefore ''
    for _imperm_f in ${lib.escapeShellArgs persistedFiles}; do
      if ! findmnt -- "$_imperm_f" >/dev/null 2>&1; then
        rm -f -- "$_imperm_f"
      fi
    done
  '';

  # programs.fuse.userAllowOther = true;
}
