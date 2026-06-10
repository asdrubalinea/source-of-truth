{ pkgs, ... }:
{
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [ "irene" ];

  # Cross-build aarch64 closures under qemu-user, so tempest can build the
  # zephyr (Raspberry Pi 3B+) SD image and its later system generations and push
  # them to a board that never compiles for itself. See docs/adr/0005.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

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
