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
  # Force-import the root pool. `disko-install` leaves zroot imported/active
  # under the *installer's* hostid (its EXIT trap only `umount -R`s the mount
  # point — it never `zpool export`s), so on first boot the pool looks foreign
  # to our hostId (networking.hostId) and a non-forced `zpool import` is refused,
  # dropping us into emergency mode. Forcing is safe here: this is a single-disk
  # laptop pool that is never shared with another live machine. (Alternatively,
  # `zpool export zroot` from the installer before the first boot avoids needing
  # this — but force is the robust default.)
  boot.zfs.forceImportRoot = true;

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
    devices = [ { device = "/dev/nvme0n1"; } ];
  };

  # Light local-snapshot policy on the mutable state. borg remains the offsite
  # backup; these are for instant local rollback.
  services.sanoid = {
    enable = true;
    # Service/config state: frequent, short retention (non-recursive, so the
    # /home child dataset is governed separately below).
    datasets."zroot/persist" = {
      autosnap = true;
      autoprune = true;
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 0;
    };
    # Home: the irreplaceable user data — longer retention.
    datasets."zroot/persist/home" = {
      autosnap = true;
      autoprune = true;
      hourly = 24;
      daily = 14;
      weekly = 8;
      monthly = 6;
    };
  };
}
