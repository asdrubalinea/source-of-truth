{...}: {
  # Everything structural — pool/LVM plumbing, the initrd activate-pool unit,
  # forceImportRoot, scrub/TRIM/ZED, smartd, sanoid retention — is
  # modules/zfs-on-luks.nix, shared with orchid. Only the two knobs that are
  # genuinely about this machine live here. Pool layout: disks/tempest.nix.

  # Cap the ARC at 8 GiB. Left unset, OpenZFS lets the ARC grow to nearly all of
  # RAM (~29.6 GiB observed on this 32 GiB machine), so under a heavy Nix build +
  # browser it competes with app memory and triggers ZFS's laggy ARC reclaim
  # (perceived stalls). 8 GiB still caches plenty of the hot /nix store (which
  # lives on ZFS) for eval/build while leaving ~24 GiB for everything else.
  # 8 * 1024^3 = 8589934592. Set via kernel cmdline so it applies at module load
  # in the initrd, before the root pool import. Pairs with system/memory.nix.
  boot.kernelParams = ["zfs.zfs_arc_max=8589934592"];

  # Sunday night, offset from orchid's window.
  services.zfs.autoScrub.interval = "Sun, 03:00";
}
