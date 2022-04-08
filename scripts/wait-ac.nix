{ config, pkgs, ... }:

let
  wait-ac = pkgs.writeScriptBin "wait-ac" ''
    #!${pkgs.stdenv.shell}
    until [[ $(run-on-ac echo 1) ]];
    do
      sleep 120
    done
  '';
in { environment.systemPackages = [ wait-ac ]; }
