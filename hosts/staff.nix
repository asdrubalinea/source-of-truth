{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    #../hardware/radeon.nix
    #../hardware/nvidia-prime.nix
    #../hardware/pipewire.nix
    ../desktop/fonts.nix

    #../services/ssh-secure.nix
    ../desktop/gnome.nix

    ../network/hosts.nix
  ];

  # Hardware
  boot.initrd.availableKernelModules = ["xhci_pci" "nvme" "ahci" "uas" "usb_storage" "usbhid" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];
  boot.zfs = {
    enableUnstable = true;
    forceImportAll = false;
  };
  boot.kernelParams = ["zfs.zfs_arc_max=1073741824" "nohibernate"]; # 1 GiB

  boot.supportedFilesystems = ["zfs"];

  # Enable nested virtualization
  boot.extraModprobeConfig = "options kvm_amd nested=1";

  fileSystems."/" = {
    device = "portable0/local/root";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/BBDD-3EF6";
    fsType = "vfat";
  };

  fileSystems."/nix" = {
    device = "portable0/local/nix";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "portable0/safe/home";
    fsType = "zfs";
  };

  fileSystems."/persist" = {
    device = "portable0/safe/persist";
    fsType = "zfs";
  };

  services.zfs.autoScrub = {
    enable = true;
    interval = "Sun, 01:00";
  };

  hardware.cpu.amd.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
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
    kernelPackages = pkgs.linuxPackages_latest;
  };

  networking.hostName = "staff";
  networking.wireless.enable = true;
  networking.wireless.userControlled.enable = true;
  networking.networkmanager.enable = false;
  networking.hostId = "639cf9ca";

  # Ignore power button
  services.logind.extraConfig = ''
    HandlePowerKey=ignore
  '';

  # Erase your darlings.
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r portable0/local/root@blank
  '';

  services.zfs.autoSnapshot = {
    enable = true;
    frequent = 8; # keep the latest eight 15-minute snapshots (instead of four)
    monthly = 1; # keep only one monthly snapshot (instead of twelve)
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

  users = {
    mutableUsers = false;
    extraUsers.root.hashedPassword = (import ../passwords).password;

    users.giovanni = {
      isNormalUser = true;
      extraGroups = ["wheel" "libvirtd"];
      hashedPassword = (import ../passwords).password;
    };
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [git sudo polkit_gnome zfs];

  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;

  nix = {
    package = pkgs.nixVersions.stable;
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
