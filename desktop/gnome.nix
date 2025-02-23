{ pkgs, ... }: {
  services.xserver.enable = true;

  services.xserver = {
    displayManager = {
      gdm.enable = true;
      sessionPackages = with pkgs; [ sway ];
    };
    desktopManager.gnome.enable = true;
  };

  services.gnome.gnome-settings-daemon.enable = true;
  services.gnome.core-utilities.enable = true;
  services.gnome.core-shell.enable = true;

  environment.gnome.excludePackages = with pkgs; [
    gnome.cheese
    gnome-photos
    gnome.gnome-music
    gnome.gnome-terminal
    gnome.gedit
    epiphany
    evince
    gnome.gnome-characters
    gnome.totem
    gnome.tali
    gnome.iagno
    gnome.hitori
    gnome.atomix
    gnome.geary
  ];

  environment.systemPackages = with pkgs; [
    gnome.gnome-tweaks
    gnome.gnome-themes-extra
    gnome.gnome-control-center
    gnome.gnome-shell-extensions
  ];
}
