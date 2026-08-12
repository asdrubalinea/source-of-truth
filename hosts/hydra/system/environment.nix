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
    # Terminfo only (no alacritty build) so ssh from tempest, which runs
    # TERM=alacritty, gets a known terminal here.
    alacritty.terminfo
  ];

  environment.variables = {
    EDITOR = "${pkgs.helix}/bin/hx";
  };
}
