{
  pkgs,
  inputs,
  ...
}: {
  # Frecency-ranked directory jumping. Enabled as a program rather than
  # dropped into desktop/home-packages.nix because the binary does nothing
  # without the shell hook that records every visit — same reasoning as the
  # nix-index and starship integrations in homes/tempest/default.nix.
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    # Shadow cd with zoxide: plain `cd <fragment>` jumps by frecency, `cdi`
    # picks interactively. `builtin cd` still reaches the real one.
    options = ["--cmd" "cd"];
  };

  programs.fish = {
    enable = true;

    # fish 4.8.0 (nixpkgs-home) dropped share/fish/tools/, so the man-page
    # completion generator create_manpage_completions.py is gone — but the
    # pinned home-manager still calls it unconditionally (programs/fish.nix:670),
    # breaking every <pkg>-fish-completions build. Disable the man-page-derived
    # completions; fish's built-in + package-shipped completions remain. Revisit
    # (drop this line) once home-manager guards the missing script.
    generateCompletions = false;

    shellAliases = import ./aliases.nix {inherit pkgs inputs;};

    shellAbbrs = {};

    interactiveShellInit = ''
      set fish_greeting # Disable greeting

      # ${pkgs.blahaj}/bin/blahaj -s

      function fish_right_prompt
      end
    '';

    plugins = [
      {
        name = "grc";
        src = pkgs.fishPlugins.grc.src;
      }
    ];
  };
}
