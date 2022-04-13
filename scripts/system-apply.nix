{ config, pkgs, configPath, ... }: {

  systemApply = pkgs.writeScriptBin "system-apply" ''
    #!${pkgs.stdenv.shell}
    pushd ${configPath}

    nixos-rebuild switch --flake '.#'

    popd
  '';
}
