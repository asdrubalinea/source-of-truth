{pkgs, ...}: {
  # ZFS for the hosts whose root pool sits on LVM-on-LUKS with a tmpfs root:
  # tempest and orchid. Both layouts use the same names (VG `pool`, LV
  # `pool/root`, pool `rpool`, datasets `rpool/persist` and `.../home`), so this
  # is layout policy, not per-machine tuning. Each host still sets its own ARC
  # cap and scrub window in system/zfs.nix, and its hostId in
  # system/networking.nix. Layout reasoning: ADR 0001.

  boot.supportedFilesystems = ["zfs"];
  boot.initrd.supportedFilesystems = ["zfs"];

  # boot.zfs.package is deliberately NOT set, and deliberately not pinned
  # either. The module default is pkgs.zfs — whatever nixpkgs considers stable —
  # which is the intent, and every ZFS attribute currently declares the same
  # kernel guard anyway, so there is nothing the LTS kernel needs from
  # zfs_unstable. A pin would only defer a major bump rather than review it, and
  # the recovery path doesn't need one: boot the previous generation and the old
  # module comes back with it.
  #
  # That rollback works only while the on-disk format stays readable by the
  # older release, so: do NOT run `zpool upgrade` on rpool just because
  # `zpool status` suggests it, unless you're ready to give up the rollback.

  # Not forced, and kept as an explicit `false` rather than deleted — forcing
  # bypasses the one safeguard against importing a pool another live system
  # holds, which is worth being visibly off rather than merely absent.
  #
  # Steady-state boots don't need it (a successful import stamps the hostid into
  # the pool labels). It was on for one case: `disko-install` never exports, so
  # a fresh pool is left active under the installer's hostid. That recurs on
  # every ./disk-install — i.e. during disaster recovery — so it's closed at the
  # source instead: ./disk-install runs `zpool export rpool` and fails loudly if
  # that fails. Keep the two in sync; this is only safe while it exports.
  #
  # If a boot ever does refuse, add `zfs_force=1` to the kernel cmdline for that
  # one boot rather than turning this on. NOTE that hatch disappears under
  # modules/secure-boot.nix — systemd-stub ignores cmdline edits on signed UKIs,
  # leaving only external rescue media.
  boot.zfs.forceImportRoot = false;

  # The rpool vdev is the LV /dev/pool/root, and because the real root is tmpfs
  # + ZFS the LV is NOT in the `fileSystems` graph — so NixOS creates no device
  # unit and never orders the import after LVM activation, relying purely on
  # udev autoactivation when the LUKS-backed PV appears. On tempest that didn't
  # fire: zfs-import-rpool polled 60s for a `pool-root` that never showed and
  # the boot dropped to emergency. (The old btrfs install never hit it — its
  # root was a tracked block device, so the VG came up as a normal dep.)
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
    # Interval is per host, so two machines sharing a UPS or backup target don't
    # scrub at the same hour.
    autoScrub.enable = true;

    # Weekly batched TRIM (gentler than continuous autotrim).
    trim.enable = true;

    # Neither host has a system MTA, so events land in the journal; set
    # ZED_EMAIL_ADDR once a system mailer exists.
    zed.settings = {
      ZED_NOTIFY_VERBOSE = true;
    };
  };

  # tempest had no SMART monitoring, so its previous disk's read errors only
  # surfaced as a failed borg run. wall, because there's no system mailer.
  # `devices` is a list, so a host with more drives appends from its own
  # system/zfs.nix rather than restating this.
  services.smartd = {
    enable = true;
    notifications.wall.enable = true;
    defaults.monitored = "-a -o on -S on -T permissive";
    devices = [{device = "/dev/nvme0n1";}];
  };

  # Local snapshots for instant rollback; borg (and tempest's external USB pool)
  # is the actual backup. Same retention on both hosts: /persist is churny
  # service state, /persist/home is the irreplaceable part. Non-recursive, so
  # the /home child is governed by its own entry.
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
