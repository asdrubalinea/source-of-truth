{
  pkgs,
  inputs,
  lib,
  ...
}:

{
  imports = [
    ../rices/hypr/fonts.nix
    ../hardware/bluetooth.nix
    ../hardware/audio.nix
  ];

  # Boot Configuration
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    initrd = {
      systemd.enable = true;

      availableKernelModules = [
        "ahci"
        "nvme"
        "sd_mod"
        "usb_storage"
        "usbhid"
        "xhci_pci"
      ];

      kernelModules = [
        "btrfs"
        "amdgpu"
      ];

      supportedFilesystems = [
        "btrfs"
        "vfat"
      ];
    };

    loader = {
      systemd-boot.enable = true;

      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot/efi";
      };
    };
  };

  # Networking
  networking = {
    hostName = "tempest";
    hostId = "856ff057";
    networkmanager.enable = true;
  };

  # Filesystems & Persistence
  fileSystems = {
    "/" = {
      fsType = "tmpfs";
      options = [
        "defaults"
        "size=2G"
        "mode=755"
      ];
    };

    "/persist" = {
      device = "/dev/pool/root";
      neededForBoot = true;
      fsType = "btrfs";
      options = [ "subvol=/@persist" ];
    };
  };

  environment.persistence."/persist" = {
    enable = true;
    hideMounts = true;
    directories = [
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/tailscale"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };

  # Hardware Configuration
  hardware = {
    enableRedistributableFirmware = true;
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

  services.xserver.videoDrivers = [ "amdgpu" ];

  # Services
  services = {
    openssh.enable = true;
    getty.autologinUser = "irene";
    fwupd = {
      enable = true;
      extraRemotes = [ "lvfs-testing" ];
    };
    logind.lidSwitch = "suspend-then-hibernate";
    power-profiles-daemon.enable = true;
    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };
  };

  # Power Management
  powerManagement = {
    cpuFreqGovernor = lib.mkDefault "powersave";
    powertop.enable = true;
  };

  # Internationalisation & Console
  time.timeZone = "Europe/Rome";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    packages = with pkgs; [ terminus_font ];
    keyMap = "us";
  };

  # Users & Security
  users.users.irene = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    hashedPassword = "$6$BkMgWYEIITYDhZkR$KnfSasOiuqi14e.85Ft/YMjgxoniRxoYXc8Tbk1J4ksq2I8Hk358V2OQFcRqHmBv/g52nhCOUWvb3uzjQuMbF0";
    shell = pkgs.fish;
  };

  security = {
    doas = {
      enable = true;
      wheelNeedsPassword = false;
    };
    sudo.enable = true;
    pam.services.greetd.enableGnomeKeyring = true;
  };

  # Nix Configuration
  nix = {
    package = pkgs.nixVersions.stable;
    settings = {
      trusted-users = [
        "root"
        "irene"
      ];
      substituters = [ "https://hyprland.cachix.org" ];
      trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
    };
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # Programs & Packages
  environment.systemPackages = with pkgs; [
    neovim
    curl
    git
  ];

  programs = {
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    dconf.enable = true;
    hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    };
    fish.enable = true;
  };

  # System Version
  system.stateVersion = "24.11";
}
