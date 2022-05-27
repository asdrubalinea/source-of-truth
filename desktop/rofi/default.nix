{ pkgs, config, ... }:

{
  xdg.configFile."rofi/config.rasi" = {
    source = ./config.rasi;
  };
}
