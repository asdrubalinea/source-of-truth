{pkgs, ...}: {
  # Login shell only. The aliases, prompt and plugins are irene's, in
  # homes/hydra.nix.
  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    git
    helix # root's editor too; irene's config is homes/hydra.nix
    openssh
    tailscale
    hyfetch
    htop
    # One-screen health readout (packages/sitrep.nix). Here rather than in
    # homes/hydra.nix so root has it too — SMART needs root: `sudo sitrep`.
    (callPackage ../../../packages/sitrep.nix {})

    # zellij, tmux and starship come with their configs from homes/hydra.nix.

    # Poking around: the aliases (homes/hydra.nix) bind ls/cat to eza/bat.
    eza
    bat
    ripgrep
    fd
    jq
    fzf
    tree
    dust
    btop
    tealdeer
    grc # the fish grc plugin (misc/fish.nix) is inert without it
    delta
    lazygit

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
