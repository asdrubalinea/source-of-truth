{ lib, config, pkgs, ... }:
{
  # Hardware platform specification
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # CPU and microcode configuration
  services.ucodenix.enable = true;
  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
    firmware = [ pkgs.linux-firmware ];

    # Enable CPU virtualization features
    cpu.amd.sev.enable = true;

    # Graphics configuration for AMD GPU
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        libvdpau-va-gl
        libva-vdpau-driver
        libva
      ];
    };

    # Peripheral support
    logitech.wireless.enable = true;
  };

  # Hardware-specific services
  services = {
    xserver.videoDrivers = [ "amdgpu" ];
    hardware.bolt.enable = true; # Thunderbolt support for Framework laptop
  };
}
