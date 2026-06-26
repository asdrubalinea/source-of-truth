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

    # Non-root access to QMK/VIA keyboard firmware. Installs qmk-udev-rules,
    # whose `KERNEL=="hidraw*" ... TAG+="uaccess"` rule grants the logged-in
    # session ACL access to /dev/hidraw*, which is what the Keychron Launcher
    # (a WebHID app) needs to talk to the keyboard. Without it the Launcher
    # shows "connected" but never responds. Use a Chromium-based browser (Brave
    # works; Firefox has no WebHID) on a wired connection.
    keyboard.qmk.enable = true;
  };

  # Hardware-specific services
  services = {
    xserver.videoDrivers = [ "amdgpu" ];
    hardware.bolt.enable = true; # Thunderbolt 4 support
  };
}
