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
    # ./system/vaultwarden-sync.nix
    ./system/environment.nix

    ./users/irene.nix

    ../../modules/nix.nix
    ../../services/caddy
  ];

  system.stateVersion = "24.11";
}
