{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./hardware.nix

    ./system/boot.nix
    ./system/localization.nix
    ./system/networking.nix
    ./system/security.nix
    ./system/services.nix
    ./system/environment.nix

    ./users/irene.nix

    ../../modules/nix.nix
  ];

  system.stateVersion = "24.11";
}
