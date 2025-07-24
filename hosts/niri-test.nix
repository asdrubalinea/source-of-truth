{ pkgs
, inputs
, lib
, config
, ...
}:

{
  imports = [
    ../rices/niri/system.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Boot Configuration
  boot = {
    kernelPackages = pkgs.linuxPackages;

    initrd = {
      availableKernelModules = [
        "virtio_pci"
        "virtio_scsi"
        "ahci"
        "xhci_pci"
        "sr_mod"
        "virtio_blk"
      ];

      kernelModules = [ ];
    };

    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
      };
    };
  };

  # Networking
  networking = {
    hostName = "niri-test";
    networkmanager.enable = true;
    useDHCP = lib.mkDefault true;
  };

  # Hardware Configuration
  hardware = {
    enableRedistributableFirmware = true;
    graphics.enable = true;
  };

  # Services
  services = {
    openssh.enable = true;

    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };

    qemuGuest.enable = true;

    # Display manager for niri
    displayManager = {
      sessionPackages = [ pkgs.niri ];
      defaultSession = "niri";
    };

    # Audio
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    # Enable D-Bus for desktop environments
    dbus.enable = true;
  };

  # XDG portal for desktop integration
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Fonts
  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      liberation_ttf
      fira-code
      fira-code-symbols
      mplus-outline-fonts.githubRelease
      dina-font
      proggyfonts
    ];
  };

  # Sound
  security.rtkit.enable = true;

  # Internationalisation & Console
  time.timeZone = "Europe/Rome";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Users & Security
  users.users.irene = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
    password = "password"; # Simple password for testing
    shell = pkgs.fish;
  };

  security = {
    doas = {
      enable = true;
      wheelNeedsPassword = false;
    };
    sudo = {
      package = pkgs.sudo-rs;
      execWheelOnly = true;
    };
    sudo-rs.enable = true;
  };

  # Nix Configuration
  nix = {
    package = pkgs.nixVersions.stable;
    settings = {
      trusted-users = [ "root" "irene" ];
      experimental-features = [ "nix-command" "flakes" ];
    };
  };

  # Basic system packages
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    firefox
    alacritty
    waybar
    tofi
  ];

  programs = {
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    # Enable fish shell system-wide
    fish.enable = true;

    # Enable niri
    niri.enable = true;
  };


  # System Version
  system.stateVersion = "24.11";
}
