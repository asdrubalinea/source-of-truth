{ ... }:
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

      # Network configuration
      "/etc/NetworkManager/system-connections"

      # Services
      "/var/lib/tailscale"
      "/var/lib/sddm"
      "/var/lib/grafana"
      "/var/lib/prometheus2"
      "/var/lib/prometheus-node-exporter"
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

  programs.fuse.userAllowOther = true;
}
