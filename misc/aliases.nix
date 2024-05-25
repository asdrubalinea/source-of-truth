{ config, pkgs, ... }:

{
  programs.fish.shellAliases = {
    gits = "git status";
    gitc = "git commit";
    gitp = "git push";
    gita = "git add";
    gitd = "git diff";
    ls = "exa";
    nv = "nvim";
    please = "doas";
    neofetch = "hyfetch";
    fetch = "hyfetch";
    fastfetch = "hyfetch";
  };
}
