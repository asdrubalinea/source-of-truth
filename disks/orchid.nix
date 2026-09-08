# The target device is NOT hard-coded — same rule as disks/tempest.nix: it must
# be passed explicitly, so an accidental run hits the placeholder and fails fast.
#   ./disk-format orchid  /dev/disk/by-id/<target>
#   ./disk-install orchid /dev/disk/by-id/<target>
#
# Inert for the booted system: disko derives `fileSystems` from GPT partlabels,
# never from this path.
{device ? "/dev/disk/by-id/REPLACE-WITH-TARGET-DEVICE-AT-INSTALL-TIME", ...}: {
  # orchid disk layout: ZFS-on-LUKS, same shape as tempest (ADR 0001).
  #
  #   GPT
  #   ├── ESP    (4G, vfat)            → /boot   (systemd-boot; UKI headroom)
  #   └── luks   (100%, LUKS2)         → "crypt"  (--sector-size 4096)
  #         └── LVM PV → VG "pool"
  #               ├── root (95%)       → zpool "rpool"
  #               └── swap (16G)       plain LV, overflow only
  #
  # Fixed at install time; none of it can change without reformatting. LUKS
  # rather than ZFS-native encryption so TPM2 auto-unlock works as on tempest —
  # which matters more here, orchid being headless with no one at the console to
  # type a passphrase. LVM so swap stays a plain LV inside one container.
  #
  # 4K alignment, on the NEW drive BEFORE disk-format:
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

    # MUST be declared here, not just as a hand-written fileSystems."/":
    # `disko-install` mounts only what lives under disko.devices, so without
    # this the install tree has no mounted root and nixos-install's systemd-boot
    # step aborts. disko emits the matching fileSystems."/" from this.
    #
    # 32G of 64G RAM, and a ceiling rather than an allocation (only used pages
    # are charged) — but /tmp lives here too, which is why the nix build
    # directory is pointed off it in system/persistence.nix.
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
          # Deliberately NOT 100%: ZFS can't shrink, so the ~5% gap is what
          # lets swap grow later.
          #
          # COUPLING: root is created before swap (alphabetical LV order), so
          # swap must fit in that ~5% — this layout needs a drive of at least
          # ~320G, and fails loudly with "insufficient free space" otherwise.
          root = {
            size = "95%";
            content = {
              type = "zfs";
              pool = "rpool";
            };
          };

          # Plain LV, NEVER a zvol (that deadlocks under memory pressure).
          # Overflow only, NOT sized for hibernation: a ZFS root forces
          # `nohibernate`, and with 64 GiB of RAM "swap >= RAM" buys nothing.
          # 16G is a cushion for a runaway build; grow it into the VG headroom
          # above if it is ever actually consumed.
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

          # Docker's data root. Its own dataset so the zfs graph driver can
          # clone one child per layer, and so image churn stays outside the
          # snapshotted /persist. Inherits com.sun:auto-snapshot=false —
          # images are re-pullable.
          docker = {
            type = "zfs_fs";
            mountpoint = "/var/lib/docker";
          };

          # Half a terabyte of re-fetchable NARs, so its own dataset: never on
          # the tmpfs root, never in a snapshot, and unable to starve the pool —
          # the quota is the hard stop behind ncps' own LRU maxSize.
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
