{...}: {
  users.groups.libvirtd.members = ["irene"];

  # So orchid can build zephyr's SD image and its later generations for a board
  # that never compiles for itself, as tempest does. See ADR 0005.
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

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

    # Rootless podman as distrobox's backend, as on tempest (see
    # hosts/tempest/system/virtualization.nix for why podman and not the docker
    # above). homes/orchid.nix pins DBX_CONTAINER_MANAGER so a broken podman
    # fails loudly instead of falling through to the root daemon. dockerCompat
    # stays off — it would install a `docker` alias clashing with the daemon.
    podman = {
      enable = true;
      dockerCompat = false;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
  };

  # Both podman roots live on rpool/containers (disks/orchid.nix), off /persist
  # and out of the snapshots; the rootless default would be under $HOME.
  virtualisation.containers.storage.settings.storage.rootless_storage_path = "/var/lib/containers/rootless/$USER";

  # Without a search registry `distrobox create --image debian:latest` dies
  # with 'did not resolve to an alias'. Restated whole because `settings` is
  # freeform TOML and replaces the module default. docker.io alone, so podman
  # never prompts on an ambiguous short name.
  virtualisation.containers.registries.settings = {
    unqualified-search-registries = ["docker.io"];
    registry = [
      {location = "docker.io";}
      {location = "quay.io";}
    ];
  };

  # podman creates rootless_storage_path only if the parent is writable, and
  # /var/lib/containers is root-owned — so hand irene its own subdir.
  # /var/lib/vms/irene is the same shape for `ocelot` (ADR 0013), which runs
  # unprivileged and keeps each dev VM's state disk under the root-owned
  # rpool/vms mountpoint. Nothing here creates the datasets — see the note in
  # disks/orchid.nix.
  systemd.tmpfiles.rules = [
    "d /var/lib/containers 0711 root root -"
    "d /var/lib/containers/rootless 0711 root root -"
    "d /var/lib/containers/rootless/irene 0700 irene users -"
    "d /var/lib/vms 0711 root root -"
    "d /var/lib/vms/irene 0700 irene users -"
  ];
}
