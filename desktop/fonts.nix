{ config, pkgs, ... }:

{
  fonts = {
    enableDefaultFonts = false;
    fonts = with pkgs; [ 
      pkgs.noto-fonts
      # pkgs.fira-code
    ];

    fontconfig = {
      defaultFonts = {
        serif = [ "Noto Serif" ];
        sansSerif = [ "Noto Sans" ];
        monospace = [ "Noto Mono" ];
      };
    };
  };
}
