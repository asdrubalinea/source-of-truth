{ pkgs, ... }:
{
  # ZFS enablement for tempest (ZFS-on-LUKS). The pool layout lives in
  # disks/tempest.nix; networking.hostId is set in system/networking.nix
  # (required by ZFS). See docs/adr/0001-zfs-on-luks-tempest.md.
  #
  # This is intentionally tempest-local rather than ../../hardware/zfs.nix —
  # that module hard-codes orchid's smartd recipient and multi-NVMe device list.

  boot.supportedFilesystems = [ "zfs" ];
  boot.initrd.supportedFilesystems = [ "zfs" ];

  # boot.zfs.package is deliberately NOT set here. The module default is already
  # pkgs.zfs — nixpkgs' current stable OpenZFS line, zfs_2_4 today — and tracking
  # whatever nixpkgs considers stable is exactly the intent. Nothing to remember,
  # nothing to re-check after an update.
  #
  # This was pkgs.zfs_unstable, on the theory that the CachyOS LTS kernel needed
  # the newest OpenZFS. It does not: nixpkgs applies the same guard to every ZFS
  # attribute (kernelMinSupportedMajorMinor = "4.18", kernelMaxSupportedMajorMinor
  # = "7.0" — see pkgs/os-specific/linux/zfs/generic.nix), so even zfs_2_3 (2.3.8)
  # builds against this 6.18 kernel. Falling back to the default is also a small
  # upgrade over zfs_unstable: same version today (both 2.4.3) but not the same
  # derivation — zfs_2_4 carries a backported dedup data-corruption fix
  # (openzfs#18366, unreleased as of 2.4.3) and is the attribute nixpkgs runs its
  # zfs series tests against. dedup is off on rpool (dedupratio 1.00x) so that fix
  # is probably out of reach, but it costs nothing.
  #
  # Not pinned to pkgs.zfs_2_4 either. A pin defers a major bump rather than
  # reviewing it, and the recovery path does not depend on one: if `nix flake
  # update` ever lands a bad 2.5.x under the root pool, boot the previous
  # generation and the old module comes back with it. That works because the
  # on-disk format stays readable by the older release until `zpool upgrade`
  # enables new feature flags — and that step is always manual. So the one rule
  # this relies on: do not run `zpool upgrade` on rpool just because `zpool
  # status` suggests it, unless you are ready to give up the rollback.

  # boot.zfs.forceImportRoot is off. Steady-state boots do not need it: every
  # successful import stamps this host's id into the pool labels
  # (networking.hostId = "856ff057" in system/networking.nix, matching
  # /etc/hostid), so normal boots and post-crash recovery import fine without -f.
  #
  # It was originally on for ONE reason — the first boot after install.
  # `disko-install`'s EXIT trap only `umount -R`s the mount point, it never
  # `zpool export`s, so a fresh pool is left marked active under the installer's
  # hostid and a non-forced import refuses. That is NOT "long gone": it recurs
  # every time ./tempest-install is run, i.e. exactly during disaster recovery
  # after replacing a dead NVMe. Closed at the source instead — ./tempest-install
  # now runs `zpool export rpool` after disko-install and refuses to finish
  # quietly if that fails. Keep the two in sync: turning this off is only safe
  # while the installer exports.
  #
  # Kept as an explicit `false` rather than deleted: forcing bypasses the one
  # safeguard against importing a pool that another live system still holds, and
  # that is worth being visibly off rather than merely absent.
  #
  # Last-resort recovery, if a boot ever does refuse (e.g. the pool was imported
  # from rescue media and not exported): add `zfs_force=1` to the kernel command
  # line for that one boot — not turning this back on permanently. NOTE that this
  # hatch disappears once ../../modules/secure-boot.nix is enabled: lanzaboote
  # boots signed UKIs and systemd-stub ignores cmdline edits under Secure Boot, so
  # from then on the only fix is external rescue media. Prefer keeping the pool
  # cleanly exported over relying on the hatch.
  boot.zfs.forceImportRoot = false;

  # Cap the ARC at 8 GiB. Left unset, OpenZFS lets the ARC grow to nearly all of
  # RAM (~29.6 GiB observed on this 32 GiB machine), so under a heavy Nix build +
  # browser it competes with app memory and triggers ZFS's laggy ARC reclaim
  # (perceived stalls). 8 GiB still caches plenty of the hot /nix store (which
  # lives on ZFS) for eval/build while leaving ~24 GiB for everything else.
  # 8 * 1024^3 = 8589934592. Set via kernel cmdline so it applies at module load
  # in the initrd, before the root pool import. Pairs with system/memory.nix.
  boot.kernelParams = [ "zfs.zfs_arc_max=8589934592" ];

  # Explicitly activate the LVM volume group that backs the pool, in the initrd,
  # before the pool import. The rpool vdev is the logical volume /dev/pool/root
  # (disko ZFS-on-LVM-on-LUKS layout). Because the real root is tmpfs + ZFS, the
  # LV is NOT in the `fileSystems` dependency graph, so NixOS adds no device unit
  # for it and never orders the import after an LVM activation — it relies purely
  # on udev event autoactivation firing when the LUKS-backed PV (crypt) appears.
  # That did not happen on tempest: the initrd `zfs-import-rpool` service polls
  # for 60s, `pool-root` never shows up, and the boot drops to emergency mode.
  # (The old btrfs install never hit this — its root was /dev/mapper/pool-root, a
  # tracked block device, so the VG was brought up as a normal fileSystems dep.)
  # `vgchange -ay` here makes the LV deterministically present for the import.
  boot.initrd.systemd.services.activate-pool = {
    description = "Activate LVM volume group pool (holds the rpool vdev)";
    after = [ "cryptsetup.target" ];
    before = [ "zfs-import-rpool.service" ];
    wantedBy = [ "zfs-import-rpool.service" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.lvm2.bin}/bin/vgchange --activate y pool";
    };
  };

  services.zfs = {
    autoScrub = {
      enable = true;
      interval = "Sun, 03:00";
    };

    # Weekly batched TRIM (gentler than continuous autotrim).
    trim.enable = true;

    # ZFS Event Daemon: surface pool degradation / scrub errors. No system MTA
    # here (msmtp is home-manager-only), so events land in the journal; set
    # ZED_EMAIL_ADDR once a system mailer exists.
    zed.settings = {
      ZED_NOTIFY_VERBOSE = true;
    };
  };

  # SMART monitoring for the single NVMe. tempest had none, so the previous
  # disk's read errors only surfaced as a failed borg run. wall notifications
  # because there is no system mailer.
  services.smartd = {
    enable = true;
    notifications.wall.enable = true;
    defaults.monitored = "-a -o on -S on -T permissive";
    devices = [{ device = "/dev/nvme0n1"; }];
  };

  # Light local-snapshot policy on the mutable state. borg remains the offsite
  # backup; these are for instant local rollback.
  services.sanoid = {
    enable = true;
    # Service/config state: frequent, short retention (non-recursive, so the
    # /home child dataset is governed separately below).
    datasets."rpool/persist" = {
      autosnap = true;
      autoprune = true;
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 0;
    };
    # Home: the irreplaceable user data — longer retention.
    datasets."rpool/persist/home" = {
      autosnap = true;
      autoprune = true;
      hourly = 24;
      daily = 14;
      weekly = 8;
      monthly = 6;
    };
  };
}
