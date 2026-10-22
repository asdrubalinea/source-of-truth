{...}: {
  # Memory tuning for this 32 GiB ZFS laptop. Pairs with the 8 GiB ARC cap in
  # system/zfs.nix and earlyoom in system/services.nix.

  # Cold anonymous pages compress in-RAM instead of hitting the LUKS-encrypted
  # NVMe swap. The 40 GiB disk swap (disks/tempest.nix) stays as lower-priority
  # overflow.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50; # up to ~16 GiB of compressed swap
    priority = 100; # higher than the disk swap, so zram is used first
  };

  # Must be explicit — the CachyOS kernel ships zswap ON, and it interposes in
  # front of zram: it charges zram a swap slot per page while keeping the data
  # in its own pool, so slots run out (measured: 13.7 of 15.3 GiB of slots
  # holding 3 GiB of data) and the allocator spills to the disk swap under no
  # real pressure. Pages that do reach zram get compressed twice.
  boot.kernelParams = ["zswap.enabled=0"];

  boot.kernel.sysctl = {
    # INTENTIONALLY 100, not the default 60 — that default assumes slow disk
    # swap. Do not push past 100 either: >100 only pays off with an LRU file
    # cache to spare, and on ZFS the cache is the ARC, which swappiness does
    # not govern.
    "vm.swappiness" = 100;

    # Swap read-ahead only helps sequential swap; wasted CPU on zram.
    "vm.page-cluster" = 0;
  };

  # Deliberately NOT set, all tried and rejected: watermark_scale_factor (it
  # inflates the reserves earlyoom reads MemAvailable from, effectively moving
  # its trigger), vfs_cache_pressure (ZFS dentries land in slab, the resource
  # this host is shortest on), the vm.dirty_* knobs (ZFS accounts dirty data
  # per txg, not via page-cache writeback), and nmi_watchdog /
  # split_lock_mitigate / compaction_proactiveness / THP / max_map_count
  # (already tuned by the CachyOS kernel or by nixpkgs).
  #
  # Note a second module defining vm.swappiness is an eval-time conflict, not
  # a silent override.
}
