{...}: {
  # Everything structural is modules/zfs-on-luks.nix, shared with tempest — the
  # initrd activate-pool unit, forceImportRoot = false, scrub/TRIM/ZED, smartd,
  # and the sanoid retention policy. Pool layout: disks/orchid.nix. Only the two
  # per-machine knobs are here.

  # Cap the ARC at 16 GiB of the 64 GiB. Left unset, OpenZFS grows the ARC to
  # nearly all of RAM and then competes with VM guests / nix builds, paying for
  # it in laggy ARC reclaim. Set via kernel cmdline so it applies at module load
  # in the initrd, before the root pool import. 16 * 1024^3 = 17179869184.
  # While the box served Strata (2026-10-09..11) this was 1 GiB, with
  # zfs_arc_min=536870912 alongside because OpenZFS silently drops a
  # zfs_arc_max below its default minimum (1/32 of RAM, 2 GiB here); 16 GiB
  # clears that floor, so no zfs_arc_min is needed. Restore the pair from
  # git history (e702a9a) if the box goes back to serving the model.
  boot.kernelParams = ["zfs.zfs_arc_max=17179869184"];

  # An hour before tempest's, so a scrub on one host never overlaps a scrub on
  # the other (they share the upstream link the borg jobs use).
  services.zfs.autoScrub.interval = "Sun, 01:00";
}
