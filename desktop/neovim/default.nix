{ config, pkgs, ... }:

{
  xdg.configFile."nvim/init.vim".source = ./init.vim;
  home.packages = with pkgs; [ nodejs ];
}
