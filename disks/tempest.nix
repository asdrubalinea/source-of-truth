{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1"; # Specify your target disk device
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00"; # EFI System Partition type
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/efi"; # Standard EFI mount point
                mountOptions = [ "umask=0077" ];
              };
            };
            # BTRFS partition containing persistent subvolumes
            root = {
              size = "100%"; # Use remaining space
              content = {
                type = "btrfs";
                # You can label the filesystem for easier identification in NixOS config
                extraArgs = [ "-L nixos" ];
                # Common mount options applied when NixOS mounts the subvolumes below
                mountOptions = [
                  "compress=zstd" # Or compress=lz4
                  "noatime" # Or relatime
                  "discard=async" # For SSDs
                  "space_cache=v2"
                ];
                # Define the persistent subvolumes needed by the tmpfs setup
                subvolumes = {
                  # Optional: Default BTRFS subvolume, not mounted by Disko.
                  # NixOS will mount tmpfs at '/' instead.
                  # Keep it if you might want to boot directly into it for maintenance.
                  "/@" = {
                    # no mountpoint defined here
                  };
                  # Subvolume for /home (persisted)
                  "/@home" = {
                    mountpoint = "/home";
                  };
                  # Subvolume for /nix (persisted)
                  "/@nix" = {
                    mountpoint = "/nix";
                    # Nix store often benefits from no compression
                    mountOptions = [ "compress=no" ];
                  };
                  # Subvolume for /var/log (persisted)
                  "/@log" = {
                    mountpoint = "/var/log";
                  };
                  # Subvolume for persistence (e.g., with impermanence module)
                  "/@persist" = {
                    mountpoint = "/persist";
                  };
                  # Add other persistent subvolumes if needed
                  # "/@snapshots" = { mountpoint = "/.snapshots"; };
                };
              };
            };
          };
        };
      };
    };
  };
}
