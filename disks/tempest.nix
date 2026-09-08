# The target device is NOT hard-coded: it must be passed explicitly, so an
# accidental destructive run targets the bogus placeholder below and fails fast
# instead of wiping a real disk.
#   ./disk-format tempest  /dev/disk/by-id/<target>
#   ./disk-install tempest /dev/disk/by-id/<target>
# tempest's own NVMe is nvme-Corsair_MP700_PRO_SE_A8WFB416001JKK.
#
# Inert for the booted system: disko derives `fileSystems` from GPT partlabels,
# never from this path, so the placeholder is fine for the module eval.
{device ? "/dev/disk/by-id/REPLACE-WITH-TARGET-DEVICE-AT-INSTALL-TIME", ...}: {
  # tempest disk layout: ZFS-on-LUKS. See ADR 0001.
  #
  #   GPT
  #   ├── ESP    (4G, vfat)            → /boot   (lanzaboote signed UKIs)
  #   └── luks   (100%, LUKS2)         → "crypt"  (--sector-size 4096)
  #         └── LVM PV → VG "pool"
  #               ├── swap (40G)       plain LV (see the note on it below)
  #               ├── root (95%)       → zpool "rpool"
  #               └── (~5% unallocated VG headroom — see root below)
  #
  # Fixed at install time; none of it can change without reformatting. LUKS
  # rather than ZFS-native encryption so the TPM2 auto-unlock carries over, and
  # LVM so swap stays a plain LV under one LUKS container.
  #
  # 4K alignment, on the NEW drive BEFORE disk-format:
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
                # No "nofail": the ESP is required, and nofail also makes
                # disko's install-time mount exit 0 when the partlabel symlink
                # isn't ready yet (a USB target races udev) — swallowing a
                # missing /boot until systemd-boot fails on it later.
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
                # 4K sector size: align crypto to NAND pages / a 4K-LBA drive.
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
    # this it never mounts a root and nixos-install's systemd-boot step aborts.
    # disko emits the matching fileSystems."/" from this, so
    # system/persistence.nix no longer declares it.
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
          # Plain LV, NEVER a zvol: swapping onto a zvol deadlocks under
          # memory pressure. Sized 40G > 32G RAM to the "swap >= RAM"
          # hibernation rule even though hibernation does not work here and is
          # not expected to — the size is headroom kept against a future where
          # it becomes possible, since this layout can't change without a
          # reformat. boot.resumeDevice exists for the same reason.
          swap = {
            size = "40G";
            content = {
              type = "swap";
            };
          };

          # Deliberately NOT 100%: ZFS can't shrink, so once root claims the
          # space it is gone. The ~5% gap is what lets swap grow after a RAM
          # upgrade (lvextend swap into it, or lvextend root + `zpool online -e`).
          #
          # COUPLING: root is created before swap (alphabetical LV order), so
          # swap must fit in that ~5%. hosts/tempest/vm.nix sets imageSize to
          # 1024G so 5% still exceeds 40G — DON'T shrink it below ~804G or
          # disko's format step fails with "insufficient free space".
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

          # Its own dataset so it carries an independent snapshot/replication
          # policy, separate from churny service state. Crossing a dataset
          # boundary later means copying data, so the boundary is set now.
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

          # Docker's data root. Its own dataset so the zfs graph driver can
          # clone one child per layer, and so image churn stays outside
          # /persist, which is snapshotted hourly and replicated to the USB
          # pool. Inherits com.sun:auto-snapshot=false — images are re-pullable,
          # and snapshotting them would only pin deleted layers.
          docker = {
            type = "zfs_fs";
            mountpoint = "/var/lib/docker";
          };

          # podman's rootful graphroot and rootless per-user roots, pointed
          # here instead of ~/.local/share/containers by
          # hosts/tempest/system/virtualization.nix. Same reasoning as the
          # docker dataset. Unlike docker this is plain overlay on one dataset,
          # since podman has no zfs driver in rootless mode.
          containers = {
            type = "zfs_fs";
            mountpoint = "/var/lib/containers";
          };

          # ocelot state disks (ADR 0013), one sparse raw image per dev VM
          # holding that guest's home and docker layer cache. Same reasoning as
          # the two datasets above. `ocelot destroy` is the only thing that
          # deletes from here, which is what makes CONTEXT.md's blast-radius
          # claim real.
          #
          # NOTE: disko only runs at format time, so this documents the layout
          # for the next install. On a live tempest, create it once by hand:
          #   sudo zfs create -o mountpoint=/var/lib/vms rpool/vms
          vms = {
            type = "zfs_fs";
            mountpoint = "/var/lib/vms";
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
