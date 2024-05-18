{ pkgs, ... }:

{
  home.packages = with pkgs; [ rofi ];

  xdg.configFile."rofi/config.rasi" = {
    source = ./config.rasi;
  };
}
