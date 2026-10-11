{pkgs, ...}: {
  boot = {
    # CachyOS kernel, same choice as tempest. -zen4 is this CPU exactly (Ryzen 7
    # 7800X3D), with no compromise — unlike tempest, where the same variant is
    # only the closest target for a Zen5 part.
    #
    # LTS, not -latest, because nixpkgs refuses to EVALUATE when the kernel
    # outruns OpenZFS support. See hosts/tempest/system/boot.nix for the full
    # note and the zfs_cachyos escape hatch.
    #
    # No scx here, unlike tempest: scx_lavd --autopower is a laptop
    # power-vs-latency lever, and this box has neither a battery nor an
    # interactive session to protect. In-kernel EEVDF runs.
    kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-lts-lto-zen4;

    # Power: performance over idle watts, since this is a tower on mains power.
    kernelParams = [
      # Already the CachyOS default; pinned so it can't drift. Same as tempest.
      "amd_pstate=active"
      # amd-pstate-epp has no real governors, only two policies, and this picks
      # the policy at driver init, so no cpupower unit is needed. "performance"
      # forces EPP to 0 and raises the floor to nominal (4.2 GHz), so a core
      # reaches boost without first ramping up. Idle cores still drop into
      # C-states, which is what frees the thermal headroom for boost. The
      # default was powersave + balance_performance. Runtime check:
      # /sys/devices/system/cpu/cpu0/cpufreq/{scaling_governor,energy_performance_preference}.
      "cpufreq.default_governor=performance"
      # Turns off PCIe link power saving, so the NVMe drives and the 9070 XT
      # don't pay a link wake-up on the first access after going idle. Costs a
      # few watts at idle. The default was the BIOS's choice.
      "pcie_aspm.policy=performance"
      # Keep the panic trace. The CachyOS kernel builds efi-pstore in but with
      # CONFIG_EFI_VARS_PSTORE_DEFAULT_DISABLE=y, so /sys/fs/pstore had no
      # backend at all ("(null)") — which is why the 2026-10-07 death and the
      # 2026-10-09 oops left nothing behind. This registers the EFI variable
      # store as the backend; kernel.panic_on_oops below is what writes to it.
      "efi_pstore.pstore_disable=0"
    ];
    # Deliberately left alone: CPU mitigations, which stay on because ocelot
    # and cage rely on them for isolation; C-states (disabling them takes away
    # boost headroom on Zen 4); and the scheduler, preemption and HZ, which the
    # CachyOS kernel already sets (EEVDF, full preempt, 1000 Hz, LTO, znver4).

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

    # UEFI, systemd-boot. No lanzaboote/Secure Boot here (tempest keeps a
    # /var/lib/sbctl dataset for it, orchid doesn't) — adding it later means
    # `sbctl create-keys`, a dataset for the keys, and modules/secure-boot.nix.
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 16;
        # Memtest86+ as a boot-menu entry. The DIMMs run at EXPO 6000 and sat
        # at 66 C when the box died log-lessly on 2026-10-07 (one ZFS checksum
        # error eleven minutes earlier, with no disk error — corruption in the
        # RAM path). Pick it from the menu at boot; it tests at whatever speed
        # the BIOS has set, so it covers the EXPO profile as actually used.
        memtest86.enable = true;
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

  # Reboot on a kernel oops instead of limping. 2026-10-09: a general protection
  # fault in the slab allocator (corrupted freelist, inside a ZFS inode
  # allocation) killed one task, which died holding a ZFS lock; the pool then
  # wedged while the network stack kept running — tailscale served exit-node
  # traffic for two hours, ssh logins hung on /home, and only a power cut got
  # the box back. Running on after slab corruption is also the case that can
  # write garbage to the pool. panic_on_oops turns the first fault into a
  # panic; panic=10 reboots ten seconds later, long enough for efi-pstore to
  # keep the trace (systemd-pstore archives it under /var/lib/systemd/pstore,
  # persisted in system/persistence.nix). Not softlockup_panic: a soft lockup
  # can be a long but legitimate kernel task, and with the oops already a
  # panic the lockup that followed it on 10-09 cannot recur.
  boot.kernel.sysctl."kernel.panic_on_oops" = 1;
  boot.kernel.sysctl."kernel.panic" = 10;
}
