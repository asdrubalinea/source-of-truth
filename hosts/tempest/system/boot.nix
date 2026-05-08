{ pkgs, ... }:
{
  services.scx = {
    # Enable the sched_ext framework and the scx_bpfland scheduler
    enable = true;
    scheduler = "scx_bpfland"; # Prioritizes foreground interactive tasks
  };

  boot = {
    # CachyOS kernel with BORE scheduler
    kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-zen4;

    # Hibernation support
    resumeDevice = "/dev/mapper/pool-swap";

    # Kernel parameters for AMD CPU/GPU optimization
    kernelParams = [
      "microcode.amd_sha_check=off"
      "amd_pstate=guided" # Prefer guided AMD P-state for better efficiency on Ryzen AI
      "mem_sleep_default=deep" # Default to deepest available suspend state
      # "usbcore.autosuspend=-1" # Disable USB autosuspend for reliability. Consider removing this
    ];

    # KVM support for virtualization
    kernelModules = [ "kvm-amd" "i2c-dev" ];

    # Early boot configuration
    initrd = {
      systemd = {
        enable = true;
        package = pkgs.systemd;
      };

      # Hardware modules needed for boot
      availableKernelModules = [
        "nvme" # NVMe SSD support
        "xhci_pci" # USB 3.0 support
        "thunderbolt" # Framework Thunderbolt ports
        "usbhid" # USB input devices
      ];

      # Additional kernel modules for disk encryption and GPU
      kernelModules = [
        "dm-snapshot" # LVM snapshots
        "amdgpu" # AMD GPU driver
        "thunderbolt"
        "xhci_pci"
        "xhci_hcd"
      ];

      # Filesystem support for early boot
      supportedFilesystems = [
        "btrfs"
        "vfat"
      ];
    };

    # UEFI boot configuration
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot/efi";
      };
    };
  };

  # NixOS strips soft-reboot's upstream units; opt back in so
  # `systemctl soft-reboot` works (userspace-only restart, no kernel reinit).
  systemd.additionalUpstreamSystemUnits = [
    "soft-reboot.target"
    "systemd-soft-reboot.service"
  ];

  systemd.coredump.enable = false;
  # Without this, the kernel default pattern "core" dumps into the crashing
  # process's cwd — which for GUI apps is usually $HOME.
  systemd.tmpfiles.rules = [ "d /var/lib/coredump 1777 root root -" ];
  boot.kernel.sysctl."kernel.core_pattern" = "/var/lib/coredump/core.%e.%p.%s.%t";
}
