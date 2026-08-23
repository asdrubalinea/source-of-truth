{pkgs, ...}: {
  programs.fish = {
    enable = true;

    # The shared alias set (misc/aliases.nix). `hn` is dropped because it pulls
    # hackernews-tui, a rust build from a flake input, and hydra builds its own
    # closure — that would compile here. `apply` is overridden because hydra has
    # no homeConfigurations entry to switch.
    shellAliases =
      removeAttrs (import ../../../misc/aliases.nix {inherit pkgs;}) ["hn"]
      // {
        apply = "nh os switch";
        logs = "journalctl -p warning -b --no-pager";
        failed = "systemctl --failed";
        ports = "ss -tulpn";
      };
  };

  environment.systemPackages = with pkgs; [
    git
    helix
    openssh
    tailscale
    hyfetch
    htop
    # One-screen health readout (packages/sitrep.nix). Headless host with no
    # home config, so it goes in systemPackages rather than home.packages the
    # way tempest gets it. SMART needs root: `sudo sitrep`.
    (callPackage ../../../packages/sitrep.nix {})

    zellij # persistent sessions over ssh; survives the link dropping

    # Poking around: aliases above bind ls/cat to eza/bat.
    eza
    bat
    ripgrep
    fd
    jq

    # Disk and service triage on a guest with a small virtual disk. dig, ss,
    # strace and rsync are already in the base closure.
    ncdu
    duf
    lsof

    # vaultwarden runs dbBackend = "sqlite" (system/services.nix) — this is how
    # you inspect or repair that DB without a web UI.
    sqlite

    # Terminfo only (no wezterm build) so ssh from tempest, which runs
    # TERM=wezterm, gets a known terminal here.
    wezterm.terminfo
  ];

  environment.variables = {
    EDITOR = "${pkgs.helix}/bin/hx";
  };
}
