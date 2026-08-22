{pkgs, ...}: {
  boot = {
    # CachyOS kernel, same choice as tempest: upstream patches + CachyOS tunings
    # (HZ=1000, full preemption, sched_ext compiled in), clang/ThinLTO.
    #
    # -zen4 is `-march=znver4`, which is this CPU exactly (Ryzen 7 7800X3D,
    # Raphael). No compromise here, unlike tempest — where the same variant is
    # the closest available target for a Zen5 part.
    #
    # LTS (not -latest) because ZFS is out-of-tree and nixpkgs refuses to
    # *evaluate* when the kernel outruns OpenZFS support: every ZFS attribute
    # caps at kernelMaxSupportedMajorMinor = "7.0" and -latest is already past
    # it, so the zfs-kernel derivation goes meta.broken and the rebuild dies
    # before compiling anything. See hosts/tempest/system/boot.nix for the full
    # note, including the boot.zfs.package = zfs_cachyos escape hatch.
    #
    # No scx / services.scx here, unlike tempest: scx_lavd --autopower is a
    # laptop power-vs-latency lever, and this box has neither a battery nor an
    # interactive session to protect. The in-kernel EEVDF scheduler runs.
    kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-lts-lto-zen4;

    kernelModules = [
      "kvm-amd"
      # Raphael's small RDNA2 iGPU — no discrete card in this machine, so this is
      # what drives the console (and would drive a display server later).
      "amdgpu"
    ];

    # Nested virtualization for libvirtd guests.
    extraModprobeConfig = ''
      options kvm_amd nested=1
    '';

    initrd = {
      # systemd in the initrd: required for the disko-generated crypttab flow
      # and for TPM2 auto-unlock via systemd-cryptenroll (see
      # docs/orchid-install.md).
      systemd.enable = true;

      availableKernelModules = [
        "nvme"
        "ahci"
        "sd_mod"
        "xhci_pci"
        "usbhid"
        # USB mass storage, so recovery/install media enumerates in the initrd.
        "uas"
        "usb_storage"
      ];

      kernelModules = [
        "dm-snapshot" # LVM
        "amdgpu"
      ];

      # zfs is added by system/zfs.nix.
      supportedFilesystems = ["vfat"];
    };

    # UEFI, systemd-boot. No lanzaboote/Secure Boot on this host (tempest keeps
    # a /var/lib/sbctl dataset for it; orchid does not) — adding it later means
    # `sbctl create-keys`, a dataset for the keys, and importing
    # modules/secure-boot.nix.
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 16;
      };
      timeout = 5;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
  };

  systemd.coredump.enable = false;
  # Without this, the kernel default pattern "core" dumps into the crashing
  # process's cwd — which on a tmpfs root means RAM.
  systemd.tmpfiles.rules = ["d /var/lib/coredump 1777 root root -"];
  boot.kernel.sysctl."kernel.core_pattern" = "/var/lib/coredump/core.%e.%p.%s.%t";

  # Full Magic SysRq, so a wedged box can be brought down with
  # Alt+SysRq+S,U,B (sync -> remount-ro -> reboot) instead of a power cut —
  # cheap insurance for the ZFS pool. Default was 16 (sync only).
  boot.kernel.sysctl."kernel.sysrq" = 1;
}
