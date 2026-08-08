{ pkgs, ... }:

let
  cage = pkgs.writeShellApplication {
    name = "cage";
    # passt provides pasta(1), used by `cage --isolate-net` to give the sandbox
    # outbound connectivity from inside its own network namespace.
    runtimeInputs = with pkgs; [ bubblewrap zellij coreutils gnugrep procps passt ];
    text = builtins.readFile ./cage.sh;
  };
in
{
  home.packages = [ cage ];
}