{ ... }:
{
  # Virtualization configuration for development
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [ "irene" ];

  virtualisation = {
    # QEMU/KVM virtualization
    libvirtd.enable = true;
    spiceUSBRedirection.enable = true;

    # Docker containers
    docker.enable = true;
  };
}
