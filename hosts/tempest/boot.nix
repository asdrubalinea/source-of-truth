{ pkgs, ... }:
{
  boot = {
    # Use recent kernel for Framework hardware support
    kernelPackages = pkgs.stable.linuxPackages_6_17;

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
        package = pkgs.stable.systemd;
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

  services.kmscon = {
    enable = true;        # use kmscon instead of gettys on VTs
    hwRender = true;      # optional: GPU rendering (can help performance)
    extraConfig = ''
      font-name=Fira Code
      font-size=16
      xkb-layout=us
      # xkb-variant=
      # xkb-options=caps:escape
    '';
  };

  systemd.coredump.enable = false;
}
