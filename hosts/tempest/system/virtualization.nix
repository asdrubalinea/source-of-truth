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

    # Rootless podman, as the backend for distrobox (installed from
    # desktop/home-packages.nix). distrobox autodetects podman before docker, so
    # nothing else has to point at it; homes/tempest pins DBX_CONTAINER_MANAGER
    # anyway so a broken podman fails loudly instead of silently falling through
    # to the root daemon below.
    #
    # podman rather than the already-present docker because distrobox's whole
    # premise is a container that shares your $HOME and your uid: rootless
    # podman maps the container's root to irene via subuid/subgid, so files
    # written into $HOME from inside come out irene-owned without a root daemon
    # in the path. (No subuid/subgid config needed here — users-groups.nix
    # defaults autoSubUidGidRange to true for every isNormalUser that doesn't
    # set ranges explicitly, so /etc/sub{u,g}id already has irene's 65536.)
    #
    # dockerCompat stays off: it would install a `docker` alias and clash with
    # virtualisation.docker above. The two coexist otherwise — separate state
    # dirs and non-overlapping default subnets (172.17/16 vs 10.88/16).
    podman = {
      enable = true;
      dockerCompat = false;

      # Images are re-pullable, and a stale distrobox base image is the usual
      # way this dataset grows without bound. Weekly prune of dangling layers.
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
  };

  # Keep container storage off /persist, for the same reason virtualisation.
  # docker gets its own dataset: /persist is snapshotted hourly by sanoid and
  # replicated to the external USB pool (docs/adr/0002), and a distrobox base
  # image is a couple of GB of churn that would be pinned in every snapshot.
  #
  # The default rootless path is $HOME/.local/share/containers/storage, which on
  # this host lands squarely inside rpool/persist/home — hence the override.
  # Both roots now live on rpool/containers (disks/tempest.nix), which inherits
  # com.sun:auto-snapshot=false.
  #
  # If `podman info` ever reports graphDriverName "vfs" instead of "overlay",
  # the kernel refused an unprivileged overlayfs mount over ZFS; fix by adding
  # pkgs.fuse-overlayfs and setting storage.options.mount_program rather than
  # living with vfs, which full-copies every layer.
  virtualisation.containers.storage.settings.storage.rootless_storage_path = "/var/lib/containers/rootless/$USER";

  # Resolve unqualified image names. Without this, `distrobox create --image
  # debian:latest` dies with 'short-name "debian:latest" did not resolve to an
  # alias and no unqualified-search-registries are defined' — the NixOS default
  # for this option emits only `[[registry]] location = …` stanzas, which are
  # per-registry *config* blocks (mirrors, insecure, blocked) and do NOT make a
  # registry searchable. Short-name resolution reads exactly one key, and it is
  # unset by default. (Docker has no equivalent problem: dockerd hard-codes
  # docker.io, which is why images "just worked" on this host until now.)
  #
  # The whole attrset is restated rather than adding one key, because settings
  # is a freeform TOML option — defining any part of it discards the module
  # default instead of merging with it, so the two location stanzas have to be
  # carried over by hand.
  #
  # docker.io alone, deliberately. Listing several search registries makes
  # podman prompt for a choice on every ambiguous short name (and simply fail
  # when non-interactive). Images elsewhere — the distrobox/toolbx bases on
  # quay.io and ghcr.io — are still reachable, just spell them fully qualified:
  # `--image quay.io/toolbx-images/debian-toolbox:12`.
  virtualisation.containers.registries.settings = {
    unqualified-search-registries = ["docker.io"];
    registry = [
      {location = "docker.io";}
      {location = "quay.io";}
    ];
  };

  # rootless_storage_path is created by podman, but only if the parent is
  # writable — /var/lib/containers is root-owned, so hand irene its own subdir.
  systemd.tmpfiles.rules = [
    "d /var/lib/containers 0711 root root -"
    "d /var/lib/containers/rootless 0711 root root -"
    "d /var/lib/containers/rootless/irene 0700 irene users -"
  ];
}
