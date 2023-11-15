{ config, lib, pkgs, ... }:

{
  imports = [
    ../network/hosts.nix
  ];

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "rpool/local/root";
      fsType = "zfs";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/0694-89A6";
      fsType = "vfat";
    };

  fileSystems."/nix" =
    { device = "rpool/local/nix";
      fsType = "zfs";
    };

  fileSystems."/home" =
    { device = "rpool/safe/home";
      fsType = "zfs";
    };

  fileSystems."/persist" =
    { device = "rpool/safe/persist";
      fsType = "zfs";
    };

  fileSystems."/mnt/docker" = {
    device = "rpool/local/docker";
    fsType = "zfs";
  };

  swapDevices = [ ];

  networking.hostName = "orchid"; # Define your hostname.
  networking.hostId = "f00dbabe";

  networking.interfaces.enp13s0.ipv4.addresses = [ {
    address = "10.0.0.10";
    prefixLength = 20;
  } ];

  networking.defaultGateway = "10.0.0.1";
  networking.nameservers = [ "10.0.0.3" ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  boot.zfs = {
    enableUnstable = true;
    forceImportAll = false;
  };

  boot.kernelParams = [
    "zfs.zfs_arc_max=1073741824" # 1 GiB
    "nohibernate"
  ];

  boot.supportedFilesystems = [ "zfs" ];

  # Enable nested virtualization
  boot.extraModprobeConfig = ''
    options kvm_amd nested=1
  '';

  services.zfs.autoScrub = {
    enable = true;
    interval = "Sun, 01:00";
  };

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableAllFirmware = true;

  # nixpkgs.config.allowUnfree = true;

  boot = {
    loader = {
      systemd-boot.enable = true;
      grub = {
        copyKernels = true; # For better ZFS compatibility
        enableCryptodisk = true;
      };
    };

    loader.efi.canTouchEfiVariables = true;
    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
  };

  # Erase your darlings.
  # boot.initrd.postDeviceCommands = lib.mkAfter ''
  #  zfs rollback -r rpool/local/root@blank
  #'';

  services.zfs.autoSnapshot = {
    enable = true;
    frequent = 10; # keep the latest ten 15-minute snapshots
    monthly = 4; # keep only four monthly snapshot
  };

  time.timeZone = "Europe/Rome";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    packages = with pkgs; [ terminus_font ];
    keyMap = "us";
  };

  users = {
    mutableUsers = false;
    extraUsers.root.hashedPassword = (import ../passwords).password;

    users.irene = {
      isNormalUser = true;
      extraGroups = [ "wheel" "libvirtd" "docker" "jackaudio" ];
      hashedPassword = (import ../passwords).password;
      shell = pkgs.fish;
    };
  };

  security.sudo.enable = true;
  security.doas.enable = true;

  security.doas.extraRules = [{
    users = [ "irene" ];
    keepEnv = true;
    noPass = true;
  }];

  environment.systemPackages = with pkgs; [
    zfs
    neovim
    git
    swtpm
    git-crypt
  ];

  programs.fish.enable = true;
  programs.mosh.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.tailscale.enable = true;
  services.openssh.enable = true;

  virtualisation.spiceUSBRedirection.enable = true;

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      swtpm.enable = true;
      ovmf.enable = true;
      ovmf.packages = [ pkgs.OVMFFull ];
    };
  };

  environment.sessionVariables.VAGRANT_DEFAULT_PROVIDER = [ "libvirt" ];
  environment.sessionVariables.LIBVIRT_DEFAULT_URI = [ "qemu:///system" ];

  virtualisation.docker = {
    enable = true;
    extraOptions = "--data-root=/mnt/docker";
  };

  users.users."irene".openssh.authorizedKeys.keys =
    [ (import ../ssh-keys/looking-glass.nix).key ];

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # networking.firewall.allowedTCPPorts = [ 8000 24800 ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  system.stateVersion = "23.05";
}

