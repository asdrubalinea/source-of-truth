{ pkgs, ... }:
{
  boot = {
    # Use recent kernel for Framework hardware support
    kernelPackages = pkgs.linuxPackages_zen;

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
    kernelModules = [ "kvm-amd" ];

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

  systemd.coredump.enable = false;
}
