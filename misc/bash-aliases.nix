{ config, pkgs, ... }:

{
  programs.bash.shellAliases = {
    gits = "git status";
    gitc = "git commit";
    gitp = "git push";
    gita = "git add";
  };
}
