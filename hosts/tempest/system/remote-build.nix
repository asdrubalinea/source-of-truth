# Builds run on orchid, not on the laptop.
#
# Every derivation tempest's daemon would build locally is shipped to orchid
# over ssh instead, so `apply`, `nh home switch` and a plain `nix build` all
# offload without any flag. Substitution is unaffected: tempest still pulls
# from its own caches first, and only what no cache has gets built.
#
# Reuses the ssh access the two hosts already have: irene's key (the shared
# `irene@orchid` one, authorized in hosts/orchid/users/irene.nix) and irene's
# trusted-user status on orchid (modules/nix.nix). The daemon runs as root and
# reads the key from irene's home; it is never copied anywhere.
#
# If orchid is off or unreachable, the build falls back to running here, so a
# rebuild never fails just because the desktop is asleep. While orchid's slots
# are busy, builds queue for it rather than spilling onto the laptop.
#
# ponytail: away from home this still goes over Tailscale, and copying a large
# closure back can take longer than building it locally would. Pass
# `-- --option builders ""` to `nh os switch` for a one-off local build.
{
  nix = {
    distributedBuilds = true;
    buildMachines = [
      {
        # Short name, as irene's own ssh config resolves it (MagicDNS search
        # domain); the knownHosts entry below must use the same name.
        hostName = "orchid";
        sshUser = "irene";
        sshKey = "/home/irene/.ssh/id_ed25519";
        protocol = "ssh-ng";
        system = "x86_64-linux";
        # Ryzen 7 7800X3D, 16 threads. Each job then gets orchid's own `cores`
        # (all of them), so this caps parallel derivations, not threads.
        maxJobs = 8;
        speedFactor = 4;
        supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      }
    ];
    # orchid fetches build inputs from its own substituters instead of tempest
    # uploading them, which matters over Tailscale.
    settings.builders-use-substitutes = true;
  };

  # The daemon connects as root, whose known_hosts is empty on the tmpfs root;
  # without this the first build stalls on a host-key check and falls back local.
  programs.ssh.knownHosts.orchid = {
    hostNames = ["orchid" "orchid.boreal-city.ts.net"];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDtM+7B7kVx9/QtqMSNwn57Yif3GHaNBEJDjVnUlcx1I";
  };
}
