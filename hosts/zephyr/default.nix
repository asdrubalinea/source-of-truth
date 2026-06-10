{ modulesPath, ... }:
{
  imports = [
    # Bootable, auto-expanding aarch64 SD image: generic-extlinux + U-Boot +
    # Raspberry Pi firmware and Pi 3/4 device trees, booting the *mainline*
    # nixpkgs kernel on a Pi 3B+. No nixos-hardware raspberry-pi-3 module (it
    # pins a vendor kernel) and no disko (this module partitions itself and the
    # root ext4 auto-expands on first boot). See docs/adr/0005.
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")

    ./hardware.nix

    ./system/localization.nix
    ./system/networking.nix
    ./system/services.nix
    ./system/security.nix
    ./system/environment.nix

    ./users/irene.nix

    ../../modules/nix.nix
  ];

  system.stateVersion = "25.11";
}
