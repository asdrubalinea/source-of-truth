# hydra's home: the headless half of ./orchid.nix, attached as a NixOS module
# (flake.nix) so `nh os switch` stays the one activation — a server has no
# reason to carry a second one. Shaped like ./ocelot.nix, the other home with no
# display, minus ../desktop/cli-packages.nix: that set is a workstation's (LSPs,
# runtimes, agent CLIs) and hydra is a 4-vCPU guest on a small disk. Packages
# stay in hosts/hydra/system/environment.nix; this file is the config.
{
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    inputs.stylix.homeModules.stylix
    ../desktop/helix.nix
    ../desktop/tmux.nix
    ../desktop/zellij.nix
    ../desktop/starship.nix
    ../desktop/ssh.nix
    ../desktop/hyfetch.nix
    ../misc/fish.nix
  ];

  # The rice's terminal half, for the same reason as ./ocelot.nix: hydra is only
  # ever seen through an ember terminal over ssh, and without a palette zellij,
  # helix and fish fall back to their stock themes inside it.
  stylix = {
    enable = true;
    base16Scheme = ../rices/ember/ember-3400k-dark.yaml;
    polarity = "dark";

    # Off, then the targets by name — autoEnable would pull fonts onto a machine
    # with no display. See ./ocelot.nix.
    autoEnable = false;
    targets = {
      zellij.enable = true;
      fish.enable = true;
      helix.enable = true;
      tmux.enable = true;
      starship.enable = true;
    };
  };

  # The shared set minus `hn` (hackernews-tui, a rust build from a flake input),
  # with `apply` cut down to the one activation this host has. mkForce because
  # ../misc/fish.nix sets the whole shared set and an attr can't be unset by
  # merging; removeAttrs is lazy, so hackernews-tui is never even evaluated.
  programs.fish.shellAliases = lib.mkForce (
    removeAttrs (import ../misc/aliases.nix {inherit pkgs;}) ["hn"]
    // {
      apply = "nh os switch";
      logs = "journalctl -p warning -b --no-pager";
      failed = "systemctl --failed";
      ports = "ss -tulpn";
    }
  );

  programs.git = {
    enable = true;
    signing.format = null;
    settings.user = {
      name = "Irene";
      email = "git@irene.foo";
    };
  };

  # Not programs.nix-index: its database is built per machine, and building one
  # is a long, memory-hungry job for this guest.

  home = {
    username = "irene";
    homeDirectory = "/home/irene";
    stateVersion = "24.11";
  };
}
