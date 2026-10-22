{pkgs, ...}: {
  # The sandbox user for nix-bench (/persist/strata/nix-bench.md): coding agents
  # under test run as this user, in a clone of this repo under its home, and
  # are graded with `nix eval`. It exists because on this machine doas for
  # wheel is passwordless (modules/security.nix), so an agent running as irene
  # could `apply` the system in one command. nixbench is not in wheel, owns
  # nothing but its home, and gets to the nix daemon like any user (evaluating
  # needs no privilege; the flake inputs are already in the store).
  #
  # Home on /persist directly rather than under /home: the tmpfs root only
  # binds /home/irene (modules/impermanence-root.nix), and this way the clones,
  # transcripts and results survive a reboot without another bind.
  # No password: reach it from irene with `doas -u nixbench -s`.
  users.users.nixbench = {
    isNormalUser = true;
    description = "nix-bench sandbox for coding agents";
    home = "/persist/strata/nix-bench/home";
    createHome = true;
    shell = pkgs.bash;
    extraGroups = [];
  };
}
