{ pkgs, ... }:

let
  cage = pkgs.writeShellApplication {
    name = "cage";
    runtimeInputs = with pkgs; [ bubblewrap zellij coreutils gnugrep procps ];
    text = builtins.readFile ./cage.sh;
  };
in
{
  home.packages = [ cage ];
}