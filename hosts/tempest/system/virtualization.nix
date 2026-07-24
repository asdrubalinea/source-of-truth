{pkgs, ...}: {
  programs.virt-manager.enable = false;
  users.groups.libvirtd.members = ["irene"];

  # Cross-build aarch64 closures under qemu-user, so tempest can build the
  # zephyr (Raspberry Pi 3B+) SD image and its later system generations and push
  # them to a board that never compiles for itself. See docs/adr/0005.
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

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

    # Docker containers. The data root is the dedicated rpool/docker dataset
    # (disks/tempest.nix) mounted at /var/lib/docker — on this host the root is
    # tmpfs, so without its own dataset every image layer would live in RAM and
    # vanish on reboot. Keeping it off /persist also keeps container layers out
    # of the sanoid snapshot + syncoid-to-USB replication scope.
    #
    # storageDriver is pinned rather than left to auto-detection: the NixOS
    # module only puts the zfs CLI on dockerd's PATH when this is set explicitly
    # (docker.nix: `optional (cfg.storageDriver == "zfs") boot.zfs.package`), and
    # without it dockerd walks its priority list past the drivers ZFS can't back
    # and lands on vfs, which full-copies every layer.
    docker = {
      enable = true;
      storageDriver = "zfs";
    };
  };
}
