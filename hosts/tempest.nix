# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Enable ZFS
  # boot.supportedFilesystems = [ "zfs" ];
  # boot.initrd.supportedFilesystems = [ "zfs" ]; # Ensure initrd can handle ZFS pool discovery
  # services.zfs.autoScrub.enable = true;

  networking.hostName = "tempest"; # Define your hostname.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.
  networking.hostId = "856ff057";

  # Configure LUKS device unlocking in initrd
  # These device paths depend on the partition labels/UUIDs created by Disko.
  # Double-check these match the PARTLABELs in /dev/disk/by-partlabel/ after Disko runs.
  boot.initrd.luks.devices = {
    "cryptroot" = {
      device = "/dev/disk/by-partlabel/cryptroot";
      preLVM = true;
      allowDiscards = true;
    };
  };

  # Configure Bootloader (GRUB for LUKS unlock)
  # disko-install with --write-efi-boot-entries handles the EFI side.
  # These settings ensure GRUB itself is configured correctly within NixOS.
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev"; # Let NixOS manage the ESP path
    useOSProber = false;
    enableCryptodisk = true;
  };

  # Hibernation
  # powerManagement.resumeDevice = "/dev/mapper/cryptswap";

  time.timeZone = "Europe/Rome";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    packages = with pkgs; [ terminus_font ];
    keyMap = "us";
  };

  users.users.irene = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  security.doas.enable = true;
  security.sudo.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    curl
    git
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  system.copySystemConfiguration = true;
  system.stateVersion = "24.11";
}
