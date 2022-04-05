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
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "ahci" "uas" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.zfs = {
    enableUnstable = true;
    forceImportAll = false;
  };
  boot.kernelParams = [ "zfs.zfs_arc_max=1073741824" ]; # 1 GiB

  boot.supportedFilesystems = [ "zfs" ];

  fileSystems."/" =
    { device = "rpool/local/root";
      fsType = "zfs";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/CA3A-6C8E";
      fsType = "vfat";
    };

  fileSystems."/nix" =
    { device = "rpool/local/nix";
      fsType = "zfs";
    };

  fileSystems."/home" =
    { device = "data/safe/home";
      fsType = "zfs";
    };

  fileSystems."/persist" =
    { device = "data/safe/persist";
      fsType = "zfs";
    };

  services.zfs.autoScrub.enable = true;

  swapDevices =
    [ { device = "/dev/disk/by-uuid/041b137f-c9a8-460f-9f6f-1abf3c3aee22"; }
    ];

  # hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;

  nixpkgs.config.allowUnfree = true;

  boot = {
    loader = {
      systemd-boot.enable = true;
      grub = {
        copyKernels = true; # For better ZFS compatibility
        enableCryptodisk = true;
      };
    };
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_zen;
  };

  networking.hostName = "swan"; # Define your hostname.
  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.wireless.userControlled.enable = true;
  networking.networkmanager.enable = false;
  networking.hostId = "ea0b4bc7";

  # Ignore power button
  services.logind.extraConfig = ''
    HandlePowerKey=ignore
  '';

  # Erase your darlings.
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r rpool/local/root@blank
  '';

  services.zfs.autoSnapshot = {
    enable = true;
    frequent = 8; # keep the latest eight 15-minute snapshots (instead of four)
    monthly = 1;  # keep only one monthly snapshot (instead of twelve)
  };

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
    hashedPassword = "$6$zoryNxhYWhQmxGPf$zRNZH/JU0/WeYcHjQhc8r/KUOYNbqzGT0a8Xh/Mb2s2GHZ1verBK1dCJrJWZoREnWGZ4E6nzdCAhDKOCwylk/1";
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

