{pkgs}: {
  # The one thing nh doesn't do in a single call: system + home in order.
  # nh resolves the flake from NH_FLAKE and homeConfigurations from
  # $USER@$HOSTNAME, so this is host-agnostic.
  apply = "nh os switch && nh home switch -b backup";

  gits = "${pkgs.git}/bin/git status";
  gitc = "${pkgs.git}/bin/git commit";
  gitp = "${pkgs.git}/bin/git push";
  gita = "${pkgs.git}/bin/git add";
  gitd = "${pkgs.git}/bin/git diff";
  ls = "${pkgs.eza}/bin/exa";
  cat = "${pkgs.bat}/bin/bat";
  # nv = "${pkgs.neovim}/bin/nvim";
  please = "${pkgs.doas}/bin/doas";
  neofetch = "${pkgs.hyfetch}/bin/hyfetch";
  fetch = "${pkgs.hyfetch}/bin/hyfetch";
  hn = "${pkgs.hackernews-tui}/bin/hackernews_tui";
}
