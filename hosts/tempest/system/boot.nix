{ pkgs, ... }:
{
  services.scx = {
    # Enable the sched_ext framework and the scx_bpfland scheduler
    enable = true;
    scheduler = "scx_bpfland"; # Prioritizes foreground interactive tasks
  };

  boot = {
    # CachyOS kernel with BORE scheduler
    # LTS (not -latest): ZFS is out-of-tree and nixpkgs refuses to evaluate when
    # the kernel outruns OpenZFS support. LTS keeps CachyOS/BORE + scx on a base
    # zfs_unstable supports. See docs/adr/0001-zfs-on-luks-tempest.md.
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
    kernelModules = [ "kvm-amd" "i2c-dev" ];

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
  systemd.tmpfiles.rules = [ "d /var/lib/coredump 1777 root root -" ];
  boot.kernel.sysctl."kernel.core_pattern" = "/var/lib/coredump/core.%e.%p.%s.%t";

  # Full Magic SysRq for an orderly emergency reboot when the desktop locks up.
  # The kernel keeps servicing SysRq through most GPU/compositor freezes, so
  # Alt+SysRq+R,E,I,S,U,B (sync -> remount-ro -> reboot) flushes dirty buffers
  # and quiesces the filesystems instead of a raw power cut — and a clean
  # power-off is the cheapest defense against the lost-write corruption that
  # forced the old btrfs root read-only (75 unsafe shutdowns on this drive; see
  # crash/crash_report.md). At minimum use S -> U -> B. Default was 16 (sync
  # only); 1 enables all functions.
  boot.kernel.sysctl."kernel.sysrq" = 1;
}
