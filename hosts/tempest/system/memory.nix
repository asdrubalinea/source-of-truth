{...}: {
  # Memory-resilience tuning for this 32 GiB ZFS laptop. Pairs with the 8 GiB
  # ARC cap in system/zfs.nix and the existing earlyoom in system/services.nix
  # (whose RAM-only trigger stays correct regardless of how full zram gets —
  # you want intervention based on real RAM headroom, not compressed swap).

  # Compressed RAM swap. Cold anonymous pages compress in-RAM (zstd, ~2.5:1 and
  # near-free on Zen5) instead of being written out to the LUKS-encrypted NVMe
  # swap — faster fault-back, no crypto overhead, no SSD wear/power. The 40 GiB
  # disk swap (disks/tempest.nix) stays as a lower-priority overflow: zram
  # (priority 100) fills first, disk only catches extreme spillover.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50; # up to ~16 GiB of compressed swap
    priority = 100; # higher than the disk swap, so zram is used first
  };

  # zswap must be turned off EXPLICITLY: the CachyOS kernel ships it enabled by
  # default, and it interposes itself in front of *every* swap device — zram
  # included — which is actively harmful here.
  #
  # Two failure modes, both measured on this host 2026-08-01:
  #
  # 1. Slot exhaustion. The swap slot on the device is allocated before zswap
  #    sees the page; if zswap keeps that page in its own pool, zram is charged
  #    for the slot but never receives the data. Result: 13.7 GiB of zram's
  #    15.3 GiB of slots in use while holding only 3 GiB of real data. Once the
  #    slots ran out the allocator fell through to the priority -2 disk swap and
  #    wrote 4.6 GiB to the LUKS-encrypted NVMe — precisely the "extreme
  #    spillover only" case this file exists to prevent, reached with no extreme
  #    memory pressure at all.
  #
  # 2. Double compression. Pages that do reach zram are compressed by zswap,
  #    decompressed again on zswap writeback, then recompressed by zram — three
  #    CPU passes to end up in the same place either layer would have used: RAM.
  #
  # zswap is a write cache designed to spare a slow backing device. zram is not
  # a slow backing device. Pick one; here it is zram.
  boot.kernelParams = ["zswap.enabled=0"];

  boot.kernel.sysctl = {
    # zram makes swapping cheap, so bias the kernel toward reclaiming anonymous
    # pages to zram rather than evicting file cache. The default of 60 is tuned
    # for slow disk swap; 100 is the standard value once swap is zram-backed.
    # INTENTIONALLY HIGH — do not "restore" this to 60.
    #
    # Do NOT push this past 100 either, however often zram guides suggest
    # 150-180. Values >100 only pay off when there is a meaningful LRU file
    # cache to spare, and on a ZFS root there mostly isn't: the file cache here
    # is the ARC, which lives outside the page-cache LRU and is not governed by
    # swappiness at all. Raising it just makes anonymous reclaim more aggressive
    # with no file side to trade against.
    "vm.swappiness" = 100;

    # Disable swap read-ahead. It only helps rotational/sequential swap; for
    # random-access zram it just wastes CPU decompressing pages nothing asked for.
    "vm.page-cluster" = 0;
  };

  # --- Deliberately NOT set ---
  #
  # vm.watermark_scale_factor (left at the kernel default 10). Tried at 125 and
  # reverted. Two reasons, in order:
  #
  # 1. It is not a CachyOS setting. CachyOS-Settings' only sysctl file is
  #    usr/lib/sysctl.d/70-cachyos-settings.conf and it does not mention
  #    watermark_scale_factor anywhere — the value came from general "tuning
  #    guide" folklore, not from the distro this host is modelled on. (What IS a
  #    CachyOS-ism is vm.watermark_boost_factor = 0, and the kernel already
  #    applies that: /proc/sys/vm/watermark_boost_factor reads 0 here against a
  #    vanilla default of 15000. Nothing to declare.)
  #
  # 2. It silently re-calibrates earlyoom. earlyoom (system/services.nix) decides
  #    on MemAvailable, and si_mem_available() subtracts totalreserve_pages and
  #    two wmark_low terms — all three of which this sysctl inflates. At 125 the
  #    measured cost on this host was ~1.4 GiB shaved off reported MemAvailable
  #    (~4.5 points of the 30.6 GiB MemTotal), which turns freeMemThreshold = 5
  #    into a real trigger near 9.5%: earlyoom would SIGTERM the browser or an
  #    in-flight nix build at ~2.9 GiB genuinely free instead of ~1.5 GiB.
  #
  # If this is ever revisited, note the arithmetic the original attempt got wrong:
  # __setup_per_zone_wmarks() sets low = min + tmp and high = min + 2*tmp, so the
  # reserve is TWICE the min→low runway you are aiming for. On this machine's
  # Normal zone (managed 7570766 pages = 28.9 GiB, not ~31), 125 reserves ~720 MiB
  # total, not the ~400 MiB the min→low figure suggests. And judge it on
  # arcstats hit rate, not just pgscan_direct vs pgscan_kswapd — raising the
  # watermark always shifts scanning toward kswapd, so that criterion cannot fail.
  #
  # vm.vfs_cache_pressure (left at 100). Lowering it to 50, as CachyOS-flavoured
  # guides suggest, retains more dentries and inodes — which on ZFS land in slab.
  # That spends precisely the resource this host is shortest on, and the one
  # already inflating every "used memory" readout (SUnreclaim is ~2 GiB here
  # before any tuning).
  #
  # vm.dirty_ratio / vm.dirty_bytes / vm.dirty_background_*. These bound
  # page-cache writeback, which is not the path a ZFS root uses — ZFS accounts
  # dirty data per transaction group in its own module parameters. Tuning them
  # here does not produce the effect it produces on ext4 or btrfs.
  #
  # kernel.nmi_watchdog, kernel.split_lock_mitigate, vm.compaction_proactiveness.
  # The CachyOS kernel already ships these tuned (all three read 0 on the running
  # kernel), so redeclaring them here would add noise, not behaviour. Same for
  # THP, which arrives as always / defer+madvise. And vm.max_map_count is already
  # raised to 1048576 by nixpkgs itself, not by us.
  #
  # NOTE: any second module defining boot.kernel.sysctl."vm.swappiness" cannot
  # simply be imported alongside this one — two plain definitions of the same
  # sysctl are an option conflict at eval time, not a silent override. (This
  # warned about modules/gaming.nix, which has since been deleted as unimported.)
}
