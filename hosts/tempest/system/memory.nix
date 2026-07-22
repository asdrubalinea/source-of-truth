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
