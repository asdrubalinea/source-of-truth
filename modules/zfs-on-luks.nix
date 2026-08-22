{pkgs, ...}: {
  # ZFS enablement for the hosts whose root pool sits on LVM-on-LUKS with a
  # tmpfs root: tempest (disks/tempest.nix) and orchid (disks/orchid.nix). Both
  # layouts use the same names — VG `pool`, LV `pool/root`, pool `rpool`,
  # datasets `rpool/persist` and `rpool/persist/home` — so everything below is
  # layout policy rather than per-machine tuning. What each host still sets for
  # itself, in its own system/zfs.nix: the ARC cap and the scrub window.
  #
  # networking.hostId (required by ZFS) stays per host, in system/networking.nix.
  # Reasoning behind the layout: docs/adr/0001-zfs-on-luks-tempest.md.
  #
  # This replaces the old hardware/zfs.nix, which was shared in name only — it
  # hard-coded orchid's two-NVMe smartd list and a mail recipient with no MTA,
  # and pinned boot.zfs.package = zfs_unstable.

  boot.supportedFilesystems = ["zfs"];
  boot.initrd.supportedFilesystems = ["zfs"];

  # boot.zfs.package is deliberately NOT set. The module default is already
  # pkgs.zfs — nixpkgs' current stable OpenZFS line, zfs_2_4 today — and tracking
  # whatever nixpkgs considers stable is exactly the intent. Nothing to remember,
  # nothing to re-check after an update.
  #
  # This was pkgs.zfs_unstable, on the theory that the CachyOS LTS kernel needed
  # the newest OpenZFS. It does not: every ZFS attribute currently declares the
  # same guard (kernelMinSupportedMajorMinor = "4.18", kernelMaxSupportedMajorMinor
  # = "7.0" — set per-version in pkgs/os-specific/linux/zfs/{2_3,2_4,unstable}.nix
  # and enforced by generic.nix), so even zfs_2_3 (2.3.8) builds against the 6.18
  # LTS kernel both hosts run. Falling back to the default is also a small upgrade
  # over zfs_unstable: same version today (both 2.4.3) but not the same derivation
  # — zfs_2_4 carries a backported dedup data-corruption fix (openzfs#18366,
  # unreleased as of 2.4.3) and is the attribute nixpkgs runs its zfs series tests
  # against. dedup is off on rpool (dedupratio 1.00x) so that fix is probably out
  # of reach, but it costs nothing.
  #
  # Not pinned to pkgs.zfs_2_4 either. A pin defers a major bump rather than
  # reviewing it, and the recovery path does not depend on one: if `nix flake
  # update` ever lands a bad 2.5.x under a root pool, boot the previous generation
  # and the old module comes back with it. That works because the on-disk format
  # stays readable by the older release until `zpool upgrade` enables new feature
  # flags — and that step is always manual. So the one rule this relies on: do not
  # run `zpool upgrade` on rpool just because `zpool status` suggests it, unless
  # you are ready to give up the rollback.

  # Not forced. Steady-state boots do not need it: every successful import stamps
  # the host's id into the pool labels (networking.hostId, matching /etc/hostid),
  # so normal boots and post-crash recovery import fine without -f.
  #
  # It was originally on for ONE reason — the first boot after install.
  # `disko-install`'s EXIT trap only `umount -R`s the mount point, it never
  # `zpool export`s, so a fresh pool is left marked active under the installer's
  # hostid and a non-forced import refuses. That is NOT "long gone": it recurs
  # every time ./disk-install is run, i.e. exactly during disaster recovery after
  # replacing a dead NVMe. Closed at the source instead — ./disk-install runs
  # `zpool export rpool` after disko-install and refuses to finish quietly if that
  # fails. Keep the two in sync: this staying false is only safe while the
  # installer exports.
  #
  # Kept as an explicit `false` rather than deleted: forcing bypasses the one
  # safeguard against importing a pool that another live system still holds, and
  # that is worth being visibly off rather than merely absent.
  #
  # Last-resort recovery, if a boot ever does refuse (e.g. the pool was imported
  # from rescue media and not exported): add `zfs_force=1` to the kernel command
  # line for that one boot — not turning this back on permanently. NOTE that this
  # hatch disappears on a host that enables modules/secure-boot.nix: lanzaboote
  # boots signed UKIs and systemd-stub ignores cmdline edits under Secure Boot, so
  # from then on the only fix is external rescue media. Prefer keeping the pool
  # cleanly exported over relying on the hatch.
  boot.zfs.forceImportRoot = false;

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
    after = ["cryptsetup.target"];
    before = ["zfs-import-rpool.service"];
    wantedBy = ["zfs-import-rpool.service"];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.lvm2.bin}/bin/vgchange --activate y pool";
    };
  };

  services.zfs = {
    # The window is per host (services.zfs.autoScrub.interval in its own
    # system/zfs.nix) so two machines that might share a UPS or a backup target
    # don't scrub at the same hour.
    autoScrub.enable = true;

    # Weekly batched TRIM (gentler than continuous autotrim).
    trim.enable = true;

    # ZFS Event Daemon: surface pool degradation / scrub errors. Neither host has
    # a system MTA (msmtp on tempest is home-manager-only), so events land in the
    # journal; set ZED_EMAIL_ADDR once a system mailer exists.
    zed.settings = {
      ZED_NOTIFY_VERBOSE = true;
    };
  };

  # SMART monitoring for the root NVMe. tempest had none, so its previous disk's
  # read errors only surfaced as a failed borg run. wall notifications because
  # there is no system mailer. `devices` is a list, so a host with more drives
  # appends to it from its own system/zfs.nix rather than restating this one.
  services.smartd = {
    enable = true;
    notifications.wall.enable = true;
    defaults.monitored = "-a -o on -S on -T permissive";
    devices = [{device = "/dev/nvme0n1";}];
  };

  # Local snapshots for instant rollback; borg (and, on tempest, the external USB
  # pool) remains the actual backup. Retention is deliberately the same on both
  # hosts: /persist is churny service state, /persist/home is the irreplaceable
  # part. Non-recursive, so the /home child dataset is governed by its own entry.
  services.sanoid = {
    enable = true;
    datasets."rpool/persist" = {
      autosnap = true;
      autoprune = true;
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 0;
    };
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
