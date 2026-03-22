{ pkgs, ... }:
let
  configApply = pkgs.writeScriptBin "config-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /persist/source-of-truth

    nixos-rebuild switch --flake '.#hydra' --sudo

    popd
  '';

  systemClear = pkgs.writeScriptBin "system-clear" ''
    #!${pkgs.stdenv.shell}
    nix-env -p /nix/var/nix/profiles/system --delete-generations old
    nix-collect-garbage -d
    nix-store --gc
    nix-store --optimize
  '';
in
{
  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    configApply
    git
    helix
    openssh
    systemClear
    tailscale
    hyfetch
    htop
  ];

  environment.variables = {
    EDITOR = "${pkgs.helix}/bin/hx";
  };
}
