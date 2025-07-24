{ config, pkgs, ... }:
{
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;

  environment.systemPackages = with pkgs.kdePackages; [
    ark
    dolphin
    kate
    kcalc
    konsole
    okular
    spectacle
    kwalletmanager
    filelight
    gwenview
    partitionmanager
  ];

  programs.kdeconnect.enable = true;
}
