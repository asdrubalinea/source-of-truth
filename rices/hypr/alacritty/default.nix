{ pkgs, config, ... }:

{
  xdg.configFile."alacritty/alacritty.toml".source = ./alacritty.toml;
  home.packages = with pkgs; [ alacritty comic-mono ];
}
