{ pkgs, ... }:
{
  boot = {
    initrd = {
      availableKernelModules = [
        "ahci"
        "xhci_pci"
        "nvme"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [ ];
    };

    kernelModules = [
      "kvm-amd"
      "amdgpu"
    ];
    extraModulePackages = [ ];
    kernelPackages = pkgs.linuxPackages_zen;

    kernelParams = [
      "zfs.zfs_arc_max=51539607552" # 48 GiB
      "nohibernate"
    ];

    # Enable nested virtualization
    extraModprobeConfig = ''
      options kvm_amd nested=1
    '';

    loader = {
      systemd-boot.enable = true;
      grub = {
        copyKernels = true; # For better ZFS compatibility
        enableCryptodisk = true;
        configurationLimit = 16;
      };
      timeout = 5;
      efi.canTouchEfiVariables = true;
    };
  };
}
