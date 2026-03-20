{ ... }:
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

      supportedFilesystems = [
        "ext4"
      ];
    };

    loader = {
      grub.enable = true;
    };
  };

  systemd.coredump.enable = false;
}
