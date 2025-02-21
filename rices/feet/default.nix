{ pkgs, ... }: {
  imports = [
    ./alacritty.nix
    ./hyprland.nix
    ./waybar.nix
    ./wallpaper
  ];
}
