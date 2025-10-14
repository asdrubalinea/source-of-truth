{ pkgs, ... }:
{
  # Virtualization configuration for development
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [ "irene" ];

  virtualisation = {
    # QEMU/KVM virtualization
    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;
        # ovmf = {
        #  enable = true;
        #  packages = [ pkgs.OVMFFull.fd ];
        #};
      };
    };
    spiceUSBRedirection.enable = true;

    # Docker containers
    docker.enable = true;
  };

  # Ensure KVM kernel modules are available
  boot.kernelModules = [ "kvm-amd" ];
}
