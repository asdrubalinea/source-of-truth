{ config, lib, pkgs, ... }:

{
  imports = [
    ../network/hosts.nix
    ../rices/hypr/fonts.nix

    ../options/passthrough.nix
    ../hardware/rocm.nix
  ];

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" "amdgpu" ];
  boot.extraModulePackages = [ ];

  vfio.enable = true;

  #specialisation."VFIO".configuration = {
  #  system.nixos.tags = [ "with-vfio" ];
  #vfio.enable = true;
  #};

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

  # Erase your darlings
  systemd.tmpfiles.rules = [
    "L /var/lib/tailscale - - - - /persist/var/lib/tailscale"
  ];

  # networking.interfaces.enp14s0.ipv4.addresses = [ {
    # address = "10.0.0.11";
    # prefixLength = 20;
  # } ];

  # networking.defaultGateway = "10.0.0.1";
  networking.defaultGateway = "10.0.0.78";
  networking.nameservers = [ "1.1.1.1" ];
  networking.useDHCP = false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  boot.zfs = {
    package = pkgs.zfs_unstable;
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

  # programs.steam = {
    # enable = true;
    # remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    # dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  # };

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
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r rpool/local/root@blank
  '';

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
      extraGroups = [ "wheel" "libvirtd" "docker" "jackaudio" "render" "video" ];
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

    # sunshine

    # lutris
    # wineWowPackages.waylandFull
    # protonup-qt
  ];

  programs.fish.enable = true;
  programs.mosh.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # For VSCode Support
  programs.nix-ld.enable = true;

  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "server";

  services.openssh.enable = true;
  services.openssh.settings.X11Forwarding = true;

  virtualisation.docker = {
    enable = true;
    extraOptions = "--data-root=/mnt/docker";
  };

  users.users."irene".openssh.authorizedKeys.keys =
    [ (import ../ssh-keys/looking-glass.nix).key ];

  nix = {
    package = pkgs.nixFlakes;
    settings.trusted-users = [ "root" "irene" ];
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # services.xserver.enable = true;

  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;
  # hardware.pulseaudio.enable = false;

  # services.xserver.windowManager.windowmaker.enable = true;

  # services.displayManager.sddm.wayland.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;

  # hardware.pulseaudio.enable = false;
    # services.xserver = {
    # enable = true;
    # libinput.enable = true;
    # displayManager.lightdm.enable = true;

    # desktopManager = {
      # cinnamon.enable = true;
    # };

    # displayManager.defaultSession = "cinnamon";
  # };

  # security.rtkit.enable = true;
  # services.pipewire = {
    # enable = true;
    # alsa.enable = true;
    # alsa.support32Bit = true;
    # pulse.enable = true;
    # # If you want to use JACK applications, uncomment this
    # jack.enable = true;
  # };

  # services.xrdp.enable = true;
  # services.xrdp.defaultWindowManager = "/run/current-system/sw/bin/gnome-session";
  # services.xrdp.openFirewall = true;

  # environment.gnome.excludePackages = (with pkgs; [
    # gnome-photos
    # gnome-tour
  # ]) ++ (with pkgs.gnome; [
    # cheese # webcam tool
    # gnome-music
    # gedit # text editor
    # epiphany # web browser
    # geary # email reader
    # evince # document viewer
    # # gnome-characters
    # totem # video player
    # tali # poker game
    # iagno # go game
    # hitori # sudoku game
    # atomix # puzzle game
  # ]);

  # environment.plasma5.excludePackages = with pkgs.libsForQt5; [
    # elisa
    # gwenview
    # okular
    # oxygen
    # khelpcenter
    # plasma-browser-integration
    # print-manager
  # ];

  # networking.firewall.allowedTCPPorts = [ 8000 24800 ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  system.stateVersion = "23.05";
}
