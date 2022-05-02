{ pkgs, config, ... }:

{
  xdg.configFile."alacritty/alacritty.yml".source = ./alacritty.yml;
  home.packages = with pkgs; [ unstable.alacritty ];
}
