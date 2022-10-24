{ config, pkgs, ... }:

let
  userApply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /etc/nixos/source-of-truth

    home-manager switch --flake '.#giovanni-router'

    popd
  '';

  systemApply = (pkgs.callPackage ../scripts/system-apply.nix {
    configPath = "/etc/nixos/source-of-truth";
  }).systemApply;

in
{
  imports = [
    ../scripts/system-clean.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  manual.manpages.enable = false; # TODO: remove this

  home.packages = with pkgs; [
    # System utils
    htop
    dstat
    screen
    git
    iperf
    pciutils

    userApply
    systemApply
  ];
}

