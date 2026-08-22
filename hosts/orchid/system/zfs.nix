{...}: {
  # Everything structural is modules/zfs-on-luks.nix, shared with tempest — the
  # initrd activate-pool unit, forceImportRoot = false, scrub/TRIM/ZED, smartd,
  # and the sanoid retention policy. Pool layout: disks/orchid.nix. Only the two
  # per-machine knobs are here.

  # Cap the ARC at 16 GiB of the 64 GiB. Left unset, OpenZFS grows the ARC to
  # nearly all of RAM and then competes with VM guests / nix builds, paying for
  # it in laggy ARC reclaim. Set via kernel cmdline so it applies at module load
  # in the initrd, before the root pool import. 16 * 1024^3 = 17179869184.
  boot.kernelParams = ["zfs.zfs_arc_max=17179869184"];

  # An hour before tempest's, so a scrub on one host never overlaps a scrub on
  # the other (they share the upstream link the borg jobs use).
  services.zfs.autoScrub.interval = "Sun, 01:00";
}
