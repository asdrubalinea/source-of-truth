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

  # zfs_unstable tracks the newest OpenZFS, matching the CachyOS LTS kernel.
  boot.zfs.package = pkgs.zfs_unstable;
  # Force-import the root pool. `disko-install`'s EXIT trap only `umount -R`s the
  # mount point — it never `zpool export`s — so right after install the pool can
  # be left marked active under the installer's hostid. Forcing avoids a
  # first-boot refusal; it is safe here, a single-disk laptop pool never shared
  # with another live machine.
  boot.zfs.forceImportRoot = true;

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
