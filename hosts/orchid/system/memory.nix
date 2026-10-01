{...}: {
  # Memory tuning for this 64 GiB ZFS tower, the same shape as tempest's
  # (hosts/tempest/system/memory.nix, which has the reasoning in full). Pairs
  # with the 16 GiB ARC cap in system/zfs.nix. Steady state is already a lot of
  # anonymous memory: llama-server keeps the CPU-side experts there
  # (load-mode = "none", system/llm.nix), and VM guests and nix builds come on
  # top.

  # Cold anonymous pages compress in-RAM instead of hitting the LUKS-encrypted
  # disk swap. The 16 GiB swap LV (disks/orchid.nix) stays as lower-priority
  # overflow. The experts are read on every token, so they stay hot and never
  # become candidates.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25; # up to ~16 GiB of compressed swap
    priority = 100; # higher than the disk swap, so zram is used first
  };

  # Must be explicit — the CachyOS kernel ships zswap ON, and in front of zram
  # it holds the data in its own pool while charging zram a swap slot per page,
  # so slots run out and the allocator spills to the disk swap under no real
  # pressure (measured on tempest).
  boot.kernelParams = ["zswap.enabled=0"];

  boot.kernel.sysctl = {
    # 100 is what the CachyOS kernel already runs with; stated so it can't
    # drift. Not past 100: on ZFS the file cache is the ARC, which swappiness
    # does not govern.
    "vm.swappiness" = 100;

    # Swap read-ahead only helps sequential swap; wasted CPU on zram.
    "vm.page-cluster" = 0;
  };
}
