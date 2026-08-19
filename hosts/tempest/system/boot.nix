{pkgs, ...}: {
  services.scx = {
    # Enable the sched_ext framework. scx_lavd (Latency-criticality Aware Virtual
    # Deadline) is interactive-focused like the previous scx_bpfland, but adds
    # power awareness: --autopower eases scheduling aggressiveness on battery and
    # biases work toward the Zen5c compact cores, ramping back up on AC. This sits
    # a layer below TLP's EPP/platform-profile split and complements it. If the
    # scheduler ever faults, the kernel transparently falls back to its built-in
    # scheduler, so this is a safe, one-line-reversible change.
    #
    # While an scx scheduler is loaded it governs *every* task, so the in-kernel
    # scheduler below only matters as the fallback taken when the BPF program
    # exits or faults. Picking a different kernel variant is therefore not a way
    # to change scheduling behaviour — the lever is this `scheduler` value, whose
    # enum currently also offers scx_flash, scx_p2dq, scx_rusty, scx_bpfland,
    # scx_cosmos and scx_layered among others.
    #
    # Inspect at runtime: `cat /sys/kernel/sched_ext/state` (expect "enabled")
    # and `cat /sys/kernel/sched_ext/root/ops` (expect the loaded scheduler's
    # build id, e.g. lavd_1.1.2_x86_64_unknown_linux_gnu).
    enable = true;
    scheduler = "scx_lavd";
    extraArgs = ["--autopower"];
  };

  boot = {
    # CachyOS kernel: patches + CachyOS tunings (HZ=1000, full preemption,
    # sched_ext compiled in), built with clang/ThinLTO and -march=znver4.
    # NOT the BORE scheduler — that lives in the separate linux-cachyos-bore*
    # attrs; this standard variant runs EEVDF underneath scx (verified: no
    # CONFIG_SCHED_BORE, CONFIG_SCHED_CLASS_EXT=y).
    #
    # LTS (not -latest): ZFS is out-of-tree and nixpkgs refuses to *evaluate* when
    # the kernel outruns OpenZFS support — every ZFS attribute caps out at
    # kernelMaxSupportedMajorMinor = "7.0", and -latest is already 7.1.x, so the
    # zfs-kernel derivation goes meta.broken and the rebuild dies before compiling
    # anything. LTS keeps CachyOS + scx on a base the nixpkgs ZFS supports. See
    # docs/adr/0001-zfs-on-luks-tempest.md. (If a newer kernel is ever needed, the
    # way out is upstream's per-variant CachyOS-patched ZFS:
    # boot.zfs.package = config.boot.kernelPackages.zfs_cachyos, which sets that
    # cap to "99.99" and passes --enable-linux-experimental — i.e. it removes the
    # guard rather than satisfying it, so validate it on this kernel first and
    # bump the kernel in a separate rebuild.)
    #
    # -zen4 is `-march=znver4`, which already implies AVX-512 (this CPU reports
    # avx512f/bw/dq/vl/vnni/bf16/vbmi2/vp2intersect) *plus* AMD-specific tuning,
    # so it is strictly richer than the -x86_64-v4 variant — switching to that
    # would be a downgrade, not the upgrade guides present it as. Upstream
    # exposes no znver5 target, so this is the top rung available for Krackan
    # Point.
    kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-lts-lto-zen4;

    # Swap lives here; it is NOT a hibernation resume target — ZFS root forces
    # `nohibernate`, so resume-from-disk never runs. Kept only so the param is
    # in place should hibernation ever become viable (see hardware/framework.nix).
    resumeDevice = "/dev/mapper/pool-swap";

    # Kernel parameters for AMD CPU/GPU optimization
    kernelParams = [
      "microcode.amd_sha_check=off"
      # amd_pstate active mode (amd_pstate_epp driver): genuine demand-based
      # scaling + EPP support. `guided` only writes a min/max band and lets the
      # firmware opportunistically boost to max at any load — cores pin near
      # 5 GHz even at idle — and has no EPP, so TLP's CPU_ENERGY_PERF_POLICY is
      # inert. See docs/framework-control-cpu-frequency.md.
      "amd_pstate=active"
      # No `mem_sleep_default=deep`: this firmware reports only S0/S4/S5 (no S3),
      # so "deep" is silently ignored and s2idle (S0ix) is the sole suspend state.
      # "usbcore.autosuspend=-1" # Disable USB autosuspend for reliability. Consider removing this
    ];

    # KVM support for virtualization
    kernelModules = ["kvm-amd" "i2c-dev"];

    # Early boot configuration
    initrd = {
      systemd = {
        enable = true;
      };

      # Hardware modules needed for boot
      availableKernelModules = [
        "nvme" # NVMe SSD support
        "xhci_pci" # USB 3.0 support
        "thunderbolt" # Framework Thunderbolt ports
        "usbhid" # USB input devices

        # USB mass-storage drivers, vestigial from when the root pool lived on a
        # USB SanDisk Portable SSD. Root now lives on the internal NVMe (see
        # disks/tempest.nix — nvme-Corsair_MP700_PRO_SE…), which the `nvme`
        # module above binds, so these are no longer load-bearing for boot. Kept
        # only so an external USB SSD (recovery/install media) still enumerates;
        # safe to drop if USB-boot support is no longer wanted.
        "uas" # USB Attached SCSI
        "usb_storage" # USB Bulk-Only Transport — fallback for non-UAS enclosures
      ];

      # Additional kernel modules for disk encryption and GPU
      kernelModules = [
        "dm-snapshot" # LVM snapshots
        "amdgpu" # AMD GPU driver
        "thunderbolt"
        "xhci_pci"
        "xhci_hcd"
      ];

      # Filesystem support for early boot (zfs is added by system/zfs.nix)
      supportedFilesystems = [
        "vfat"
      ];
    };

    # UEFI boot configuration. For the first install we boot with systemd-boot;
    # once sbctl keys exist, enabling modules/secure-boot.nix mkForce-disables
    # systemd-boot and switches the loader to lanzaboote.
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
  };

  systemd.coredump.enable = false;
  # Without this, the kernel default pattern "core" dumps into the crashing
  # process's cwd — which for GUI apps is usually $HOME.
  systemd.tmpfiles.rules = ["d /var/lib/coredump 1777 root root -"];
  boot.kernel.sysctl."kernel.core_pattern" = "/var/lib/coredump/core.%e.%p.%s.%t";

  # Full Magic SysRq for an orderly emergency reboot when the desktop locks up.
  # The kernel keeps servicing SysRq through most GPU/compositor freezes, so
  # Alt+SysRq+R,E,I,S,U,B (sync -> remount-ro -> reboot) flushes dirty buffers
  # and quiesces the filesystems instead of a raw power cut — and a clean
  # power-off is the cheapest defense against the lost-write corruption that
  # forced the old btrfs root read-only (75 unsafe shutdowns on the drive that
  # preceded this NVMe). At minimum use S -> U -> B. Default was 16 (sync only);
  # 1 enables all functions.
  boot.kernel.sysctl."kernel.sysrq" = 1;
}
