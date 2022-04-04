{ config, pkgs, lib, ... }:

{
  imports =
    [
      ../hardware/radeon.nix
      ../hardware/nvidia-prime.nix
      ../hardware/pipewire.nix
      ../desktop/fonts.nix

      ../services/ssh-secure.nix
      ../services/redshift.nix

      ../network/hosts.nix
    ];

  # Hardware
  # TODO: change filesystems from UUID to by-label
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "ahci" "uas" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.zfs = {
    enableUnstable = true;
    forceImportAll = false;
  };
  boot.supportedFilesystems = [ "zfs" ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/ee359a3f-dc30-4349-908c-db37fbe916cd";
      fsType = "btrfs";
      options = [ "subvol=@" ];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/ee359a3f-dc30-4349-908c-db37fbe916cd";
      fsType = "btrfs";
      options = [ "subvol=@home" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/9BDC-A196";
      fsType = "vfat";
    };
  
  services.zfs.autoScrub.enable = true;

  swapDevices = [ ];

  # hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;

  boot = {
    loader = {
      systemd-boot.enable = true;
      grub.copyKernels = true; # For better ZFS compatibility
    };
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_zen;
  };

  networking.hostName = "swan"; # Define your hostname.
  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.wireless.userControlled.enable = true;
  networking.networkmanager.enable = false;
  networking.hostId = "ea0b4bc4";

  # Ignore power button
  services.logind.extraConfig = ''
    HandlePowerKey=ignore
  '';

  # Set your time zone.
  time.timeZone = "Europe/Rome";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;
  networking.interfaces.wlp4s0.useDHCP = true;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "it";
  };

  users.users.giovanni = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  };

  # Screen sharing
  xdg = {
    portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk
      ];
      gtkUsePortal = true;
    };
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [ git sudo polkit_gnome zfs ];

  virtualisation.docker.enable = true;

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
   };

  # Polkit
  security.polkit.enable = true;

  # users.users."giovanni".openssh.authorizedKeys.keys = [
    # (import ../ssh-keys/looking-glass.nix).key
  # ];

  # networking.firewall.allowedTCPPorts = [ ...];
  # networking.firewall.allowedUDPPorts = [ ... ];

  system.stateVersion = "22.05";
}
