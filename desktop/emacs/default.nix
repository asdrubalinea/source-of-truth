{ config, pkgs, ... }:

{
  programs.emacs = {
    enable = true;
    extraPackages = epkgs: [ epkgs.vterm ];
    extraConfig = builtins.readFile ./init.el;
  };

  # Ensure git is available for Elpaca package manager
  home.packages = with pkgs; [
    git
  ];
}
