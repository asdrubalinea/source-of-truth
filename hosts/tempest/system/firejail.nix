{ pkgs, ... }: {
  programs.firejail = {
    enable = true;
    wrappedBinaries.librewolf = {
      executable = "${pkgs.librewolf}/bin/librewolf";
      profile = "${pkgs.firejail}/etc/firejail/librewolf.profile";
      desktop = "${pkgs.librewolf}/share/applications/librewolf.desktop";
      extraArgs = [
        "--private"
        "--private-tmp"
        "--private-dev"
        "--private-cache"
        "--disable-mnt"
        "--blacklist=/boot"
        "--blacklist=/srv"
        "--blacklist=/var"
        "--blacklist=/persist"
        "--blacklist=/root"
        "--caps.drop=all"
        "--noroot"
        "--nonewprivs"
        "--seccomp"
        "--protocol=unix,inet,inet6,netlink"
        "--no3d"
        "--nodvd"
        "--notv"
        "--nou2f"
        "--novideo"
        "--noprinters"
        "--machine-id"
        "--dns=9.9.9.9"
        "--dns=149.112.112.112"
        "--deterministic-shutdown"
        "--env=MOZ_ENABLE_WAYLAND=1"
      ];
    };
  };
}
