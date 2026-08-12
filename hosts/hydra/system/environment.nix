{ pkgs, ... }:
{
  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    git
    helix
    openssh
    tailscale
    hyfetch
    htop
    # Terminfo only (no wezterm build) so ssh from tempest, which runs
    # TERM=wezterm, gets a known terminal here.
    wezterm.terminfo
  ];

  environment.variables = {
    EDITOR = "${pkgs.helix}/bin/hx";
  };
}
