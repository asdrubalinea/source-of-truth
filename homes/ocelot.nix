# The guest home for an ocelot (ADR 0013), modelled on ./orchid.nix — the shape
# of a headless host's home, because that is what a guest entered over ssh is.
# The package set is ../desktop/cli-packages.nix, shared with tempest, so the
# shell inside an ocelot is the shell outside it.
{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.stylix.homeModules.stylix
    ../desktop/cli-packages.nix
    ../desktop/helix.nix
    ../desktop/tmux.nix
    ../desktop/zellij.nix # `ocelot` attaches to a zellij session, as cage does
    ../misc/fish.nix
  ];

  programs.home-manager.enable = true;

  # The rice's terminal half, the only half an ocelot can show. Without it the
  # guest rendered zellij's stock palette inside an ember terminal (its theme is
  # guarded on `config.stylix.enable`), and helix and fish fell back to their own
  # defaults too.
  #
  # cage could never have had this problem: it runs on tempest and bind-mounts
  # the host's already-generated configs, inheriting the theme as a side effect
  # of being the same machine. An ocelot is a different machine, so the result
  # has to be CONFIGURED here rather than smuggled across the boundary — which
  # is also why it stays correct when the palette changes.
  #
  # rices/ember itself is deliberately not imported: it is a desktop, and none
  # of it has a display to land on here. Only the palette is shared, being the
  # one thing a terminal and a desktop genuinely have in common.
  stylix = {
    enable = true;
    base16Scheme = ../rices/ember/ember-3400k-dark.yaml;

    # Same reason as rices/ember/stylix.nix: "either" makes every target that
    # branches on polarity pick its light side under a dark palette.
    polarity = "dark";

    # Off, then five targets by name. autoEnable would switch on the fontconfig
    # target — putting font packages in home.packages of a machine with no
    # display — plus every GUI target for programs this guest doesn't install.
    # These five are exactly the HM programs it does enable.
    autoEnable = false;
    targets = {
      zellij.enable = true;
      fish.enable = true;
      helix.enable = true;
      tmux.enable = true;
      starship.enable = true;
    };
  };

  home = {
    username = "irene";
    homeDirectory = "/home/irene";
    stateVersion = "23.05";
  };

  home.sessionVariables = {
    EDITOR = "${pkgs.helix}/bin/hx";

    # An ocelot IS the boundary, so tell anything that checks (an agent deciding
    # whether it is confined, a prompt, a script) which one it is in. cage sets
    # SANDBOXED=cage for the same purpose.
    OCELOT = "1";
  };

  programs.git = {
    enable = true;
    signing.format = null;
    settings.user = {
      name = "Irene";
      email = "git@irene.foo";
    };
  };

  programs.starship.enable = true;

  # Start in the project: an ocelot is *of* one directory, so landing in $HOME
  # and typing `cd` is a papercut on the only path anyone walks.
  #
  # Done in the guest rather than by having `ocelot enter` run `cd <path> &&
  # zellij` over ssh, because the remote shell is fish and bash's printf %q —
  # the only sane way to quote a path from the launcher — emits $'…', which fish
  # does not understand. The path is already inside, in /host/conf/project.
  #
  # Guarded on $PWD being $HOME so it fires only on a fresh login: a pane the
  # user has cd'd elsewhere, and any `ocelot ssh <cmd>`, are left alone.
  programs.fish.interactiveShellInit = ''
    if test -r /host/conf/project; and test "$PWD" = "$HOME"
      cd (cat /host/conf/project) 2>/dev/null
    end
  '';

  # Not programs.nix-index: the database is built per-machine and there is none
  # in here, so `comma` and the command-not-found handler would only ever miss.
}
