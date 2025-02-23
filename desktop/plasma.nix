{ ... }: {
  services.xserver = {
    enable = true;
    desktopManager.plasma5.enable = true;
    displayManager.lightdm.enable = true;
  };
}
