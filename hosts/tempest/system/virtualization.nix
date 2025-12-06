{ pkgs, ... }:
{
  # Virtualization configuration for development
  programs.virt-manager.enable = false;
  users.groups.libvirtd.members = [ "irene" ];

  virtualisation = {
    # QEMU/KVM virtualization
    libvirtd = {
      enable = false;
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
    docker.enable = false; # nix btw
  };
}
