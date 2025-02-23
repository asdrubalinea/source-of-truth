{ pkgs, ... }: {
  programs.fish.shellAliases = {
    gits = "${pkgs.git}/bin/git status";
    gitc = "${pkgs.git}/bin/git commit";
    gitp = "${pkgs.git}/bin/git push";
    gita = "${pkgs.git}/bin/git add";
    gitd = "${pkgs.git}/bin/git diff";
    ls = "${pkgs.exa}/bin/exa";
    nv = "${pkgs.neovim}/bin/neovim";
    please = "${pkgs.doas}/bin/doas";
    neofetch = "${pkgs.hyfetch}/bin/hyfetch";
    fetch = "${pkgs.hyfetch}/bin/hyfetch";
    fastfetch = "${pkgs.hyfetch}/bin/hyfetch";
  };
}
