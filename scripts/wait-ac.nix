{ config, pkgs, ... }: {

  wait-ac = pkgs.writeScriptBin "wait-ac" ''
    #!${pkgs.stdenv.shell}
    until [[ $(run-on-ac echo 1) ]];
    do
      sleep 120
    done
  '';
}
