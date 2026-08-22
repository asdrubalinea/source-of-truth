# The target device is NOT hard-coded — same rule as disks/tempest.nix. It must
# be passed explicitly at format/install time, so an accidental (or wrong-machine)
# run targets the bogus placeholder below and fails fast instead of wiping a disk:
#   ./disk-format orchid  /dev/disk/by-id/<target>   # disko --argstr device <target>
#   ./disk-install orchid /dev/disk/by-id/<target>   # disko-install --disk main <target>
#
# For the booted system this value is inert: disko derives `fileSystems` from GPT
# partlabels (disk-main-ESP, disk-main-luks), never from this device path, so the
# placeholder default is fine for the NixOS module eval (flake.nix → orchid).
{device ? "/dev/disk/by-id/REPLACE-WITH-TARGET-DEVICE-AT-INSTALL-TIME", ...}: {
  # orchid disk layout: ZFS-on-LUKS, same shape as tempest (docs/adr/0001).
  #
  #   GPT
  #   ├── ESP    (4G, vfat)            → /boot   (systemd-boot; UKI headroom)
  #   └── luks   (100%, LUKS2)         → "crypt"  (--sector-size 4096)
  #         └── LVM PV → VG "pool"
  #               ├── root (95%)       → zpool "rpool"
  #               └── swap (16G)       plain LV, overflow only
  #
  # Everything here is fixed at install time and cannot be changed without
  # reformatting. LUKS (not ZFS-native encryption) so TPM2 auto-unlock via
  # systemd-cryptenroll works the same way it does on tempest — which matters
  # more here, since orchid is headless and nobody wants to type a passphrase at
  # a console. LVM so swap stays a plain LV (never a zvol) inside one container.
  #
  # 4K alignment (do this on the NEW drive BEFORE running disk-format orchid):
  #   nvme id-ns /dev/nvme0n1 | grep lbaf      # find a 4096-byte LBA format
  #   nvme format /dev/nvme0n1 --lbaf=<index>  # DESTRUCTIVE — fresh drive only
  # then ashift=12 and --sector-size 4096 below align natively.
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # Supplied by the caller (see the file header). Always a stable by-id
        # path (model+serial) — NOT /dev/sdX or /dev/nvme0n1, which re-enumerate.
        device = device;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "4G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                # No "nofail" — see the note in disks/tempest.nix: nofail makes
                # disko's install-time mount exit 0 when the partlabel symlink
                # isn't ready, swallowing a missing /boot until systemd-boot
                # fails much later. Fail loudly instead.
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
                extraOpenArgs = [];
                # Format-time only — cannot change without reformatting.
                extraFormatArgs = ["--sector-size 4096"];
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
    # under disko.devices, so without this entry the install tree has no mounted
    # root and nixos-install's systemd-boot step aborts with "efiSysMountPoint =
    # '/boot' is not a mounted partition". disko emits the matching
    # fileSystems."/" from this, so system/persistence.nix doesn't declare it.
    #
    # 32G of 64G RAM. Only pages actually used are charged, so this is a ceiling,
    # not an allocation — but note /tmp lives here too, which is why the nix
    # build directory is pointed off it (system/persistence.nix).
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
          # ZFS pool vdev. Deliberately NOT 100%: ~5% of the VG is left
          # unallocated so swap can be grown later (ZFS can't shrink, so once
          # root claims the space it is gone).
          #
          # COUPLING: root (95%FREE) is created before swap (alphabetical LV
          # order), so swap must fit in the remaining ~5% — i.e. this layout
          # needs a target drive of at least ~320G. Format fails loudly with
          # "insufficient free space" otherwise.
          root = {
            size = "95%";
            content = {
              type = "zfs";
              pool = "rpool";
            };
          };

          # Plain swap LV, never a zvol (swapping onto a zvol deadlocks under
          # memory pressure). Overflow only, NOT sized for hibernation: a ZFS
          # root forces `nohibernate`, so resume-from-disk never runs, and with
          # 64 GiB of RAM the "swap >= RAM" rule buys nothing. 16G is a cushion
          # for a runaway build; grow it into the VG headroom above if it is ever
          # actually consumed.
          swap = {
            size = "16G";
            content = {
              type = "swap";
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

          # /home on its own dataset so it carries an independent snapshot
          # policy, separate from churny service state. Crossing a dataset
          # boundary later means copying data, so the boundary is set now.
          "persist/home" = {
            type = "zfs_fs";
            mountpoint = "/persist/home";
            options."com.sun:auto-snapshot" = "true";
          };

          # Docker's data root (virtualisation.docker with storageDriver =
          # "zfs"; see system/virtualization.nix). Own dataset so the zfs graph
          # driver can clone one child dataset per layer, and so image churn
          # stays outside the snapshotted /persist. Inherits
          # com.sun:auto-snapshot=false — images are re-pullable.
          docker = {
            type = "zfs_fs";
            mountpoint = "/var/lib/docker";
          };

          # ncps binary-cache store (services.ncps, system/services.nix). Half a
          # terabyte of re-fetchable NARs: own dataset so it never lands on the
          # tmpfs root, never enters a snapshot, and cannot starve the rest of
          # the pool — the quota is the hard stop behind ncps' own LRU maxSize.
          ncps = {
            type = "zfs_fs";
            mountpoint = "/var/lib/ncps";
            options.quota = "560G";
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
