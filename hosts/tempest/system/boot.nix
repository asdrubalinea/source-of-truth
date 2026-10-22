{pkgs, ...}: {
  services.scx = {
    # sched_ext. scx_lavd is interactive-focused with power awareness:
    # --autopower eases off on battery and biases work to the Zen5c compact
    # cores. A faulting scheduler transparently falls back to the in-kernel one,
    # so this is one-line reversible.
    #
    # While loaded it governs EVERY task, so the kernel variant below is only
    # the fallback — `scheduler` here is the lever, not the kernel choice.
    # Runtime check: /sys/kernel/sched_ext/state and .../root/ops.
    enable = true;
    scheduler = "scx_lavd";
    extraArgs = ["--autopower"];
  };

  boot = {
    # CachyOS patches + tunings (HZ=1000, full preempt, sched_ext), clang/ThinLTO,
    # -march=znver4. NOT BORE — that's a separate attr; this runs EEVDF under scx.
    #
    # LTS, not -latest: nixpkgs refuses to EVALUATE when the kernel outruns
    # OpenZFS support (every ZFS attr caps at kernelMaxSupportedMajorMinor 7.0,
    # -latest is 7.1.x), so the rebuild dies before compiling. See ADR 0001. The
    # way out, if a newer kernel is ever needed, is
    # `boot.zfs.package = config.boot.kernelPackages.zfs_cachyos` — but that
    # removes the guard rather than satisfying it, so validate separately.
    #
    # -zen4 already implies AVX-512 plus AMD tuning, so it is strictly richer
    # than -x86_64-v4; switching to that is a downgrade. There is no znver5
    # target upstream, so this is the top rung for Krackan Point.
    kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-lts-lto-zen4;

    # NOT a hibernation resume target — ZFS root forces `nohibernate`. Kept only
    # so the param is in place should hibernation become viable.
    resumeDevice = "/dev/mapper/pool-swap";

    kernelParams = [
      "microcode.amd_sha_check=off"
      # `active`, not `guided`: guided only writes a min/max band and lets
      # firmware boost to max at any load (cores pin near 5 GHz at idle) and has
      # no EPP, which makes TLP's CPU_ENERGY_PERF_POLICY inert.
      # See docs/framework-control-cpu-frequency.md.
      "amd_pstate=active"
      # No `mem_sleep_default=deep`: this firmware reports no S3, so "deep" is
      # silently ignored and s2idle (S0ix) is the only suspend state.
    ];

    kernelModules = ["kvm-amd" "i2c-dev"];

    initrd = {
      systemd = {
        enable = true;
      };

      availableKernelModules = [
        "nvme" # NVMe SSD support
        "xhci_pci" # USB 3.0 support
        "thunderbolt" # Framework Thunderbolt ports
        "usbhid" # USB input devices

        # Vestigial from when root lived on a USB SSD; root is on the internal
        # NVMe now. Kept only so recovery/install media still enumerates.
        "uas" # USB Attached SCSI
        "usb_storage" # USB Bulk-Only Transport — fallback for non-UAS enclosures
      ];

      kernelModules = [
        "dm-snapshot" # LVM snapshots
        "amdgpu" # AMD GPU driver
        "thunderbolt"
        "xhci_pci"
        "xhci_hcd"
      ];

      # zfs is added by system/zfs.nix
      supportedFilesystems = [
        "vfat"
      ];
    };

    # systemd-boot for the first install; once sbctl keys exist, enabling
    # modules/secure-boot.nix mkForce-disables it and switches to lanzaboote.
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
  };

  systemd.coredump.enable = false;
  # Without this the kernel's default "core" pattern dumps into the crashing
  # process's cwd — usually $HOME for GUI apps.
  systemd.tmpfiles.rules = ["d /var/lib/coredump 1777 root root -"];
  boot.kernel.sysctl."kernel.core_pattern" = "/var/lib/coredump/core.%e.%p.%s.%t";

  # Full Magic SysRq (default 16 is sync only). The kernel keeps servicing it
  # through most compositor freezes, so Alt+SysRq+R,E,I,S,U,B quiesces the
  # filesystems instead of a raw power cut — the cheapest defence against the
  # lost-write corruption that forced the old btrfs root read-only. At minimum
  # S -> U -> B.
  boot.kernel.sysctl."kernel.sysrq" = 1;
}
