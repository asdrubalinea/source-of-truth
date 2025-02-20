{ pkgs, ... }: {
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set fish_greeting # Disable greeting

      ${pkgs.blahaj}/bin/blahaj -s

      function fish_right_prompt
      end
    '';

    plugins = [
      { name = "grc"; src = pkgs.fishPlugins.grc.src; }
    ];

    shellAliases = {
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
      sudo = "doas";
      arc = "cat /proc/spl/kstat/zfs/arcstats | grep '^size ' | awk '{ print $3 }' | awk '{ print $1 / (1024 * 1024 * 1024) \" GB\" }'";
    };
  };
}
