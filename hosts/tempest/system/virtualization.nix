{pkgs, ...}: {
  programs.virt-manager.enable = false;
  users.groups.libvirtd.members = ["irene"];

  # So tempest can build zephyr's SD image and its later generations for a board
  # that never compiles for itself. See ADR 0005.
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  virtualisation = {
    libvirtd = {
      enable = false;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;
      };
    };
    spiceUSBRedirection.enable = true;

    # Data root is the dedicated rpool/docker dataset: the host root is tmpfs,
    # so without it every image layer would live in RAM and vanish on reboot.
    # Being off /persist also keeps layers out of the sanoid + syncoid scope.
    #
    # storageDriver is pinned rather than auto-detected because the NixOS module
    # only puts the zfs CLI on dockerd's PATH when it is set explicitly —
    # without it dockerd falls through to vfs, which full-copies every layer.
    docker = {
      enable = true;
      storageDriver = "zfs";
    };

    # Rootless podman as distrobox's backend. distrobox autodetects podman
    # first, and homes/tempest pins DBX_CONTAINER_MANAGER anyway so a broken
    # podman fails loudly instead of falling through to the root daemon.
    #
    # podman and not the docker above because distrobox's premise is a container
    # sharing your $HOME and uid: rootless podman maps container root to irene
    # via subuid/subgid, so files written from inside come out irene-owned with
    # no root daemon in the path. (autoSubUidGidRange already covers this.)
    #
    # dockerCompat stays off — it would install a `docker` alias clashing with
    # the daemon above. Otherwise the two coexist: separate state dirs,
    # non-overlapping default subnets.
    podman = {
      enable = true;
      dockerCompat = false;

      # A stale distrobox base image is the usual way this dataset grows without
      # bound, and images are re-pullable.
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
  };

  # Keep container storage off /persist, for the same reason docker gets its own
  # dataset: /persist is snapshotted hourly and replicated to the USB pool (ADR
  # 0002), and a distrobox base image is a couple of GB of churn that would be
  # pinned in every snapshot. The rootless default is under $HOME, i.e. squarely
  # inside rpool/persist/home — hence the override. Both roots live on
  # rpool/containers, which inherits com.sun:auto-snapshot=false.
  #
  # If `podman info` ever reports graphDriverName "vfs", the kernel refused an
  # unprivileged overlayfs mount over ZFS: add pkgs.fuse-overlayfs and set
  # storage.options.mount_program rather than living with vfs.
  virtualisation.containers.storage.settings.storage.rootless_storage_path = "/var/lib/containers/rootless/$USER";

  # Short-name resolution reads exactly one key, and it is unset by default —
  # without it `distrobox create --image debian:latest` dies with 'did not
  # resolve to an alias'. The NixOS default only emits `[[registry]]` stanzas,
  # which are per-registry config blocks and do NOT make a registry searchable.
  # The whole attrset is restated because `settings` is freeform TOML: defining
  # any part of it discards the module default rather than merging.
  #
  # docker.io alone, deliberately — several search registries make podman prompt
  # on every ambiguous short name, and fail outright when non-interactive.
  # Images on quay.io/ghcr.io are still reachable fully qualified.
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
  # rpool/vms mountpoint. Nothing here creates that dataset — disko only runs at
  # format time.
  systemd.tmpfiles.rules = [
    "d /var/lib/containers 0711 root root -"
    "d /var/lib/containers/rootless 0711 root root -"
    "d /var/lib/containers/rootless/irene 0700 irene users -"
    "d /var/lib/vms 0711 root root -"
    "d /var/lib/vms/irene 0700 irene users -"
  ];
}
