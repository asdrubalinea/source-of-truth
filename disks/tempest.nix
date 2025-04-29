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
              label = "boot";
              name = "ESP";
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/efi";
		mountOptions = [ "umask=0077" ];
              };
            };

            luks = {
              size = "100%";
              label = "luks";
              content = {
                type = "luks";
                name = "cryptroot";

                extraOpenArgs = [
		  # performance
                  "--perf-no_read_workqueue"
		  # performance
                  "--perf-no_write_workqueue"
                ];

		settings = {
                  allowDiscards = true;
                  #keyFile = "/tmp/secret.key";
                };

                # https://0pointer.net/blog/unlocking-luks2-volumes-with-tpm2-fido2-pkcs11-security-hardware-on-systemd-248.html
                # settings = {crypttabExtraOpts = ["fido2-device=auto" "token-timeout=10"];};

                content = {
                  type = "btrfs";
                  extraArgs = ["-L" "nixos" "-f"];
                  subvolumes = {
                    "/root" = {
                      mountpoint = "/";
                      mountOptions = ["subvol=root" "compress=zstd" "noatime"];
                    };
                    "/home" = {
                      mountpoint = "/home";
                      mountOptions = ["subvol=home" "compress=zstd" "noatime"];
                    };
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = ["subvol=nix" "compress=zstd" "noatime"];
                    };
                    "/persist" = {
                      mountpoint = "/persist";
                      mountOptions = ["subvol=persist" "compress=zstd" "noatime"];
                    };
                    "/log" = {
                      mountpoint = "/var/log";
                      mountOptions = ["subvol=log" "compress=zstd" "noatime"];
                    };
                    "/swap" = {
                      mountpoint = "/swap";
                      swap.swapfile.size = "64G";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}

