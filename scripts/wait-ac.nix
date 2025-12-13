{ pkgs, ... }:
{
  wait-ac = pkgs.writeScriptBin "wait-ac" ''
    #!${pkgs.stdenv.shell}

    until [[ $(${pkgs.tlp}/bin/run-on-ac echo 1) ]];
    do
      sleep 120
    done
  '';
}
