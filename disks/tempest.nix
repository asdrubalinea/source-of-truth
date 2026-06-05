# The target device is NOT hard-coded. It must be passed explicitly at
# format/install time, so accidentally running a destructive disko command (or
# running it on the wrong machine) targets the bogus placeholder below and fails
# fast instead of wiping a real disk:
#   ./tempest-format  /dev/disk/by-id/<target>   # disko --argstr device <target>
#   ./tempest-install /dev/disk/by-id/<target>   # disko-install --disk main <target>
# tempest's own NVMe is /dev/disk/by-id/nvme-Corsair_MP700_PRO_SE_A8WFB416001JKK.
#
# For the booted system this value is inert: disko derives `fileSystems` from GPT
# partlabels (disk-main-ESP, disk-main-luks), never from this device path, so the
# placeholder default is fine for the NixOS module eval (flake.nix → tempest).
{ device ? "/dev/disk/by-id/REPLACE-WITH-TARGET-DEVICE-AT-INSTALL-TIME"
, ...
}:
{
  # tempest disk layout: ZFS-on-LUKS.
  #
  #   GPT
  #   ├── ESP    (4G, vfat)            → /boot   (lanzaboote signed UKIs)
  #   └── luks   (100%, LUKS2)         → "crypt"  (--sector-size 4096)
  #         └── LVM PV → VG "pool"
  #               ├── swap (40G)       plain LV, hibernation/resume
  #               ├── root (95%)       → zpool "rpool"
  #               └── (~5% unallocated VG headroom — see root below)
  #
  # Everything in this file is fixed at install time and cannot be changed
  # without reformatting. LUKS is kept (not ZFS-native encryption) so the
  # existing TPM2 auto-unlock carries over; LVM is kept so swap stays a plain LV
  # (never a zvol) for safe hibernation under a single LUKS container.
  # See docs/adr/0001-zfs-on-luks-tempest.md.
  #
  # 4K alignment (do this on the NEW drive BEFORE running tempest-format):
  #   nvme id-ns /dev/nvme0n1 | grep lbaf      # find a 4096-byte LBA format
  #   nvme format /dev/nvme0n1 --lbaf=<index>  # DESTRUCTIVE — fresh drive only
  # then ashift=12 and --sector-size 4096 below align natively.
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # Supplied by the caller (see the file header). Always use a stable by-id
        # path (model+serial) — NOT /dev/sdX, which re-enumerates across
        # reboots/USB hotplug and could point at the wrong disk at install.
        device = device;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "4G";
              type = "EF00"; # EFI System Partition
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                # No "nofail": the ESP is required (lanzaboote writes signed
                # UKIs here). nofail also makes disko's install-time `mount`
                # exit 0 when the partlabel symlink isn't ready yet (a USB
                # target races udev), so a missing /boot is swallowed and only
                # surfaces later as the systemd-boot "efiSysMountPoint = '/boot'
                # is not a mounted partition" failure. Fail loudly instead.
                mountOptions = [
                  "defaults"
                  "nosuid"
                  "nodev"
                  "umask=0077"
                ];
              };
            };

            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypt";
                extraOpenArgs = [ ];
                # 4K sector size: align crypto to NAND pages / a 4K-LBA drive.
                # Format-time only — cannot change without reformatting.
                extraFormatArgs = [ "--sector-size 4096" ];
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

    # tmpfs root for impermanence — MUST be declared here, not only as a
    # hand-written fileSystems."/". `disko-install` mounts *only* what lives
    # under disko.devices, so without this entry it never mounts a root:
    # /mnt/disko-install-root stays a bare directory, the install tree has no
    # mounted root, and nixos-install's systemd-boot step aborts with
    # "efiSysMountPoint = '/boot' is not a mounted partition". disko also emits
    # the matching fileSystems."/" from this, so system/persistence.nix no
    # longer declares it. (cf. disko example/hybrid-tmpfs-on-root.nix)
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "defaults"
        "size=32G"
        "mode=755"
      ];
    };

    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          # Plain swap LV (not a zvol) so hibernation is safe under ZFS.
          # boot.resumeDevice = /dev/mapper/pool-swap is set in system/boot.nix.
          # 40G > 32G RAM (hibernation needs swap >= RAM).
          swap = {
            size = "40G";
            content = {
              type = "swap";
            };
          };

          # ZFS pool vdev. Deliberately NOT 100%: leaving ~5% of the VG
          # unallocated lets swap be grown later (ZFS can't shrink, so once root
          # claims the space it is gone). After a RAM upgrade, either lvextend
          # swap into the gap, or `lvextend` root + `zpool online -e rpool ...`
          # to expand the pool.
          #
          # COUPLING: root (95%FREE) is created before swap (alphabetical LV
          # order), so swap must fit in the remaining ~5%. The tempest-vm image
          # (hosts/tempest/vm.nix) sets disko.devices.disk.main.imageSize large
          # enough (1024G) that 5% still exceeds swap's 40G — DON'T shrink that
          # imageSize below ~804G or disko's format step fails ("insufficient
          # free space") when it can't fit swap.
          root = {
            size = "95%";
            content = {
              type = "zfs";
              pool = "rpool";
            };
          };
        };
      };
    };

    zpool = {
      rpool = {
        type = "zpool";
        # Single-vdev pool on a 4K-sector NVMe.
        options.ashift = "12";

        rootFsOptions = {
          compression = "zstd";
          atime = "off";
          xattr = "sa";
          acltype = "posixacl";
          dnodesize = "auto"; # recommended pairing with xattr=sa
          mountpoint = "none";
          "com.sun:auto-snapshot" = "false";
        };

        datasets = {
          # Nix store: reproducible, never snapshotted.
          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
          };

          # Impermanence target: service/config state. Snapshotted by sanoid
          # (system/zfs.nix). neededForBoot is asserted in system/persistence.nix.
          persist = {
            type = "zfs_fs";
            mountpoint = "/persist";
            options."com.sun:auto-snapshot" = "true";
          };

          # /home split into its own dataset so it carries an independent
          # snapshot/replication policy, separate from churny service state.
          # Crossing a dataset boundary later means copying data, so the
          # boundary is set now.
          "persist/home" = {
            type = "zfs_fs";
            mountpoint = "/persist/home";
            options."com.sun:auto-snapshot" = "true";
          };

          # Secure Boot signing keys (lanzaboote pkiBundle), isolated from the
          # /persist backup scope.
          sbctl = {
            type = "zfs_fs";
            mountpoint = "/var/lib/sbctl";
          };

          # Never mounted. A refreservation we can shrink to recover from a
          # 100%-full, write-wedged pool (ZFS is copy-on-write).
          reserved = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              refreservation = "5G";
            };
          };
        };
      };
    };
  };
}
