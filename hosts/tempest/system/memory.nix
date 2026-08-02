{ ... }:
{
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
  boot.kernelParams = [ "zswap.enabled=0" ];

  boot.kernel.sysctl = {
    # zram makes swapping cheap, so bias the kernel toward reclaiming anonymous
    # pages to zram rather than evicting file cache. The default of 60 is tuned
    # for slow disk swap; 100 is the standard value once swap is zram-backed.
    # INTENTIONALLY HIGH — do not "restore" this to 60.
    "vm.swappiness" = 100;
    # Disable swap read-ahead. It only helps rotational/sequential swap; for
    # random-access zram it just wastes CPU decompressing pages nothing asked for.
    "vm.page-cluster" = 0;
  };
}
