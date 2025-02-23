{ pkgs, ... }: {
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set fish_greeting # Disable greeting
      starship init fish | source

      # ${pkgs.blahaj}/bin/blahaj -s

      function fish_right_prompt
      end
    '';

    plugins = [
      { name = "grc"; src = pkgs.fishPlugins.grc.src; }
    ];
  };
}
