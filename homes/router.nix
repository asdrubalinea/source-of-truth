{ config, pkgs, ... }:

{
  # Applying and cleaning is `nh` (NH_FLAKE=/etc/nixos/source-of-truth):
  # `nh os switch`, `nh home switch -c irene-router`, `nh clean all`.

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # System utils
    htop
    dstat
    screen
    git
    iperf
    pciutils
    ookla-speedtest
  ];
}

