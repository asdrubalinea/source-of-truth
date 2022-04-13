{ config, pkgs, ... }:

{
  programs.fish.shellAliases = {
    gits = "git status";
    gitc = "git commit";
    gitp = "git push";
    gita = "git add";
    ls = "exa";
  };
}
