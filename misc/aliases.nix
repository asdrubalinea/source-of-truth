{ pkgs, inputs, ... }: {
  programs.fish.shellAliases = {
    gits = "${pkgs.git}/bin/git status";
    gitc = "${pkgs.git}/bin/git commit";
    gitp = "${pkgs.git}/bin/git push";
    gita = "${pkgs.git}/bin/git add";
    gitd = "${pkgs.git}/bin/git diff";
    ls = "${pkgs.eza}/bin/exa";
    # nv = "${pkgs.neovim}/bin/nvim";
    please = "${pkgs.doas}/bin/doas";
    neofetch = "${pkgs.hyfetch}/bin/hyfetch";
    fetch = "${pkgs.hyfetch}/bin/hyfetch";
    hn = "${inputs.hn-tui-flake.packages.${pkgs.system}.hackernews-tui}/bin/hackernews_tui";
  };
}
