{...}: {
  users.groups.libvirtd.members = ["irene"];

  virtualisation = {
    # Headless libvirt: guests are driven with virsh (or virt-manager over ssh
    # from tempest). programs.virt-manager and spiceUSBRedirection went with the
    # desktop — both are local-GUI features.
    libvirtd = {
      enable = true;
      qemu.swtpm.enable = true;
    };

    # Docker's data root is the dedicated rpool/docker dataset (disks/orchid.nix)
    # mounted at /var/lib/docker, replacing the old --data-root=/mnt/docker
    # extraOptions: on a tmpfs root every image layer would otherwise live in RAM
    # and vanish on reboot. Keeping it off /persist also keeps layer churn out of
    # the sanoid snapshot scope.
    #
    # storageDriver is pinned rather than left to auto-detection: the NixOS module
    # only puts the zfs CLI on dockerd's PATH when this is set explicitly
    # (docker.nix: `optional (cfg.storageDriver == "zfs") boot.zfs.package`), and
    # without it dockerd walks past the drivers ZFS can't back and lands on vfs,
    # which full-copies every layer.
    docker = {
      enable = true;
      storageDriver = "zfs";
    };
  };
}
