{ pkgs, ... }:
{
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [ "irene" ];

  virtualisation = {
    # QEMU/KVM virtualization
    libvirtd = {
      enable = false;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;
      };
    };
    spiceUSBRedirection.enable = true;

    # Docker containers
    docker.enable = false; # nix btw
  };
}
