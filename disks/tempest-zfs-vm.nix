# Modified version of tempest-zfs.nix for VM testing
# Changes: /dev/nvme0n1 -> /dev/vda, reduced swap size
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/vda"; # Changed from /dev/nvme0n1 for VM
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00"; # EFI System Partition type
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/efi";
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

            boot = {
              size = "2G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/boot";
                mountOptions = [
                  "defaults"
                  "nofail"
                  "nosuid"
                  "nodev"
                  "noexec"
                ];
              };
            };

            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypt";
                extraOpenArgs = [ ];
                settings = {
                  allowDiscards = true;
                };
                content = {
                  type = "zfs";
                  pool = "zroot";
                };
              };
            };
          };
        };
      };
    };

    zpool = {
      zroot = {
        type = "zpool";
        rootFsOptions = {
          # ZFS properties for the root pool
          atime = "off";
          compression = "lz4";
          xattr = "sa";
          acltype = "posixacl";
          relatime = "on";
          canmount = "off";
          mountpoint = "none";
        };

        options = {
          ashift = "12"; # 4K sectors
        };

        datasets = {
          # Local datasets (not backed up)
          "local" = {
            type = "zfs_fs";
            options = {
              canmount = "off";
              mountpoint = "none";
            };
          };

          # Root dataset - ephemeral, rolled back on boot
          "local/root" = {
            type = "zfs_fs";
            options = {
              canmount = "noauto";
              mountpoint = "legacy";
            };
            mountpoint = "/";
            postCreateHook = ''
              zfs snapshot zroot/local/root@blank
            '';
          };

          # Nix store - preserved across boots
          "local/nix" = {
            type = "zfs_fs";
            options = {
              mountpoint = "legacy";
              atime = "off";
            };
            mountpoint = "/nix";
          };

          # Safe datasets (for backup)
          "safe" = {
            type = "zfs_fs";
            options = {
              canmount = "off";
              mountpoint = "none";
            };
          };

          # Persistent data
          "safe/persist" = {
            type = "zfs_fs";
            options = {
              mountpoint = "legacy";
            };
            mountpoint = "/persist";
          };

          # Home directories
          "safe/home" = {
            type = "zfs_fs";
            options = {
              mountpoint = "legacy";
            };
            mountpoint = "/home";
          };

          # System logs
          "safe/log" = {
            type = "zfs_fs";
            options = {
              mountpoint = "legacy";
              xattr = "sa";
              acltype = "posixacl";
            };
            mountpoint = "/var/log";
          };

          # Swap volume - reduced for VM
          "local/swap" = {
            type = "zfs_volume";
            size = "4G"; # Reduced from 36G for VM testing
            content = {
              type = "swap";
            };
          };
        };
      };
    };
  };
}