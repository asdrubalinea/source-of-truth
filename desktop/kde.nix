{ config, pkgs, ... }:
{
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  environment.systemPackages = with pkgs; [
    kdePackages.ark
    kdePackages.kate
    kdePackages.kdenlive
    kdePackages.gwenview
    kdePackages.okular
    kdePackages.spectacle
    kdePackages.filelight
    kdePackages.kcalc
  ];
}