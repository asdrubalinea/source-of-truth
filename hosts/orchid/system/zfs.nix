{...}: {
  # Everything structural is modules/zfs-on-luks.nix, shared with tempest — the
  # initrd activate-pool unit, forceImportRoot = false, scrub/TRIM/ZED, smartd,
  # and the sanoid retention policy. Pool layout: disks/orchid.nix. Only the two
  # per-machine knobs are here.

  # Cap the ARC at 1 GiB. Since 2026-10-09 this box is a dedicated LLM server:
  # Strata at IQ3_S keeps 50 GiB of experts resident and needs every other GiB
  # for the KV cache and headroom (6 GiB free at a 1 GiB ARC; 16 GiB would not
  # fit the model at all). The pool only ever serves the model's one-off load
  # from the page cache and the repo, so the ARC buys nothing here. Set via
  # kernel cmdline so it applies at module load in the initrd, before the root
  # pool import. zfs_arc_min must come down too: OpenZFS ignores a zfs_arc_max
  # below its default minimum (1/32 of RAM, 2 GiB here) — a 1 GiB cap alone is
  # silently dropped. 1 * 1024^3 = 1073741824, 512 MiB = 536870912.
  # The desktop-era cap was 16 GiB (17179869184); restore it if the box goes
  # back to VM guests and nix builds.
  boot.kernelParams = [
    "zfs.zfs_arc_min=536870912"
    "zfs.zfs_arc_max=1073741824"
  ];

  # An hour before tempest's, so a scrub on one host never overlaps a scrub on
  # the other (they share the upstream link the borg jobs use).
  services.zfs.autoScrub.interval = "Sun, 01:00";
}
