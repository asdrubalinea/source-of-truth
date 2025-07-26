{ lib, config, pkgs, ... }:
{
  # Minimal live CD configuration based on tempest
  imports = [
    # Essential hardware support for Framework laptop
    ../hardware/bluetooth.nix
    ../hardware/audio.nix
    ../hardware/framework.nix

    # Shared system modules
    ../modules/nix.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Basic boot configuration for live CD
  boot = {
    kernelPackages = pkgs.linuxPackages_6_15;
    kernelParams = [
      "microcode.amd_sha_check=off"
      "amdgpu.dcdebugmask=0x12"
      "amd_pstate=active"
    ];
    kernelModules = [ "kvm-amd" ];

    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "thunderbolt"
        "usbhid"
      ];
      kernelModules = [ "amdgpu" ];
      supportedFilesystems = [ "btrfs" "vfat" ];
    };
  };

  # Hardware configuration
  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
    firmware = [ pkgs.linux-firmware ];

    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        libvdpau-va-gl
        libva-vdpau-driver
        libva
      ];
    };
  };

  services = {
    xserver.videoDrivers = [ "amdgpu" ];
    hardware.bolt.enable = true;
  };

  # Networking for live environment
  networking = {
    hostName = "nixos-live";
    networkmanager.enable = true;
  };

  # Live CD specific packages
  environment.systemPackages = with pkgs; [
    neovim
    curl
    git
    parted
    gptfdisk
    cryptsetup
  ];

  system.stateVersion = "24.11";
}
