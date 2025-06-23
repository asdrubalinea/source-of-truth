{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/vda";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00"; # EFI System Partition type
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "defaults"
                  "nofail"
                  "nosuid"
                  "nodev"
                  "noexec"
                  "umask=0077"
                ];
              };
            };

            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };

    zpool = {
      zroot = {
        type = "zpool";
        datasets = {
          # Root dataset - not mounted, used as container
          root = {
            type = "zfs_fs";
            options = {
              canmount = "off";
              mountpoint = "none";
            };
          };

          # Local datasets (ephemeral)
          "local" = {
            type = "zfs_fs";
            options = {
              canmount = "off";
              mountpoint = "none";
            };
          };

          # Root filesystem - mounted at /
          "local/root" = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              canmount = "on";
              compression = "lz4";
            };
          };

          # Nix store - persistent
          "local/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              atime = "off";
              canmount = "on";
              compression = "lz4";
            };
          };

          # Persistent datasets
          "persist" = {
            type = "zfs_fs";
            options = {
              canmount = "off";
              mountpoint = "none";
            };
          };

          # Persist directory for impermanence
          "persist/root" = {
            type = "zfs_fs";
            mountpoint = "legacy";
            options = {
              canmount = "on";
              compression = "lz4";
            };
          };

          # Home directories
          "persist/home" = {
            type = "zfs_fs";
            mountpoint = "legacy";
            options = {
              canmount = "on";
              compression = "lz4";
            };
          };

          # Log files
          "persist/log" = {
            type = "zfs_fs";
            mountpoint = "legacy";
            options = {
              canmount = "on";
              compression = "lz4";
            };
          };
        };
      };
    };
  };
}