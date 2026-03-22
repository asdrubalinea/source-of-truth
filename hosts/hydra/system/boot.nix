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
        "virtio_pci"
        "virtio_blk"
        "virtio_scsi"
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
