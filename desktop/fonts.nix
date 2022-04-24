{ config, pkgs, ... }:

{
  fonts = {
    enableDefaultFonts = false;
    fonts = with pkgs; [ cascadia-code fira-code ];

    fontconfig = {
      defaultFonts = {
        serif = [ "Cascadia Code" ];
        sansSerif = [ "Cascadia Code" ];
        monospace = [ "Cascadia Code" ];
      };
    };
  };
}
