{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
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
                  type = "lvm_pv";
                  vg = "pool";
                };
              };
            };
          };
        };
      };
    };

    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          # BTRFS partition containing persistent subvolumes
          root = {
            size = "-36G";
            content = {
              type = "btrfs";
              extraArgs = [ "-L nixos" ];
              mountOptions = [
                "compress=lz4"
                "noatime"
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
              };
            };
          };

          swap = {
            size = "100%";
            content = {
              type = "swap";
            };
          };
        };
      };
    };
  };
}
