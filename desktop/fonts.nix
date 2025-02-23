{ pkgs, ... }:

let
  operator-mono = pkgs.callPackage ../packages/operator-mono.nix { };
in
{
  fonts = {
    enableDefaultFonts = false;
    fonts = with pkgs; [ operator-mono cascadia-code fira-code agave ];

    fontconfig = {
      defaultFonts = {
        serif = [ "Operator Mono Medium" ];
        sansSerif = [ "Operator Mono Medium" ];
        monospace = [ "Operator Mono Medium" ];
      };
    };
  };
}
