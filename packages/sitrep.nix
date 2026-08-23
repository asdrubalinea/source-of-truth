# One-screen health readout; the script itself is scripts/sitrep.sh.
#
# Split out of scripts/sitrep.nix (a home-manager module) so headless hosts
# without a home config — hydra, zephyr — can put it in
# environment.systemPackages instead.
{
  writeShellApplication,
  coreutils,
  gawk,
  gnugrep,
  gnused,
  iproute2,
  iw,
  jq,
  procps,
  smartmontools,
  systemd,
  util-linux,
}:
writeShellApplication {
  name = "sitrep";
  # Everything the script reaches for is pinned here rather than inherited
  # from the user's profile, so `sitrep` reports the same way under sudo, in a
  # systemd unit, or from a bare shell.
  #
  # zfs is deliberately NOT in this list: `zpool` must come from
  # /run/current-system/sw/bin so the userland matches the running kernel
  # module. The script feature-detects it with `command -v` and skips the pool
  # section on hosts without ZFS.
  runtimeInputs = [
    coreutils
    gawk
    gnugrep
    gnused
    iproute2
    iw
    jq
    procps
    smartmontools
    systemd
    util-linux
  ];
  text = builtins.readFile ../scripts/sitrep.sh;
}
