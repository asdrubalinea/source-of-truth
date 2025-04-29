{ inputs, ... }:

let
  diskDevicePath = inputs.main.device;

  swapSize = "40G";
in
{
  disko.devices = {
    disk = {
      main = {
        device = diskDevicePath;
        type = "gpt";
        partitions = [
          # EFI System Partition (ESP) - Unencrypted
          {
            name = "ESP";
            size = "1G";
            type = "ef00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot/efi";
            };
          }

          # LUKS Encrypted Partition for Swap
          {
            name = "cryptswap_part";
            size = swapSize;
            content = {
              type = "luks";
              name = "cryptswap"; # Mapped device: /dev/mapper/cryptswap
              # keyFile option can be added if needed
              settings = {
                allowDiscards = true;
              };
              content = {
                type = "swap"; # Mark for NixOS swap activation
              };
            };
          }

          # LUKS Encrypted Partition for ZFS (main data)
          {
            name = "cryptroot_part";
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot"; # Mapped device: /dev/mapper/cryptroot
              # keyFile option can be added if needed
              settings = {
                allowDiscards = true;
              };
              content = {
                type = "zpool";
                name = "zroot";
                rootFsOptions = {
                  canmount = "off";
                  mountpoint = "none";
                };
                options = {
                  ashift = "12";
                  autotrim = "on";
                };
                datasets = {
                  # Base datasets needed
                  "blankroot" = {
                    mountpoint = "/";
                    options.canmount = "off";
                  }; # For tmpfs overlay
                  "nix" = {
                    mountpoint = "/nix";
                  };
                  "boot" = {
                    mountpoint = "/boot";
                  }; # Kernels/initrds live here (encrypted)

                  # Base persistent directory - Used by impermanence module
                  "persist" = {
                    mountpoint = "/persist";
                  };

                  "home" = {
                    mountpoint = "/home";
                  };
                  "var/log" = {
                    mountpoint = "/var/log";
                  };
                };
              };
            };
          }
        ];
      };
    };

    # Define the root filesystem type for impermanence
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "defaults"
        "size=2G"
        "mode=755"
      ]; # Adjust tmpfs size as needed
    };
  };
}
