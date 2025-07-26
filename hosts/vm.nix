{ pkgs
, inputs
, lib
, config
, ...
}:

{
  imports = [
    ../modules/nix.nix
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

      supportedFilesystems = [
        "zfs"
        "vfat"
      ];

      postDeviceCommands = lib.mkAfter ''
        zfs rollback -r zroot/local/root@blank
      '';
    };

    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
      };
    };

    # ZFS support
    supportedFilesystems = [ "zfs" ];
    zfs.forceImportRoot = false;
  };

  # Networking
  networking = {
    hostName = "vm";
    hostId = "12345678"; # Required for ZFS
    networkmanager.enable = true;
    useDHCP = lib.mkDefault true;
  };

  # Filesystems & Persistence
  fileSystems = {
    "/" = {
      device = "zroot/local/root";
      fsType = "zfs";
    };

    "/nix" = {
      device = "zroot/local/nix";
      fsType = "zfs";
    };

    "/persist" = {
      device = "zroot/persist/root";
      fsType = "zfs";
      neededForBoot = true;
    };

    "/home" = {
      device = "zroot/persist/home";
      fsType = "zfs";
    };

    "/var/log" = {
      device = "zroot/persist/log";
      fsType = "zfs";
    };

    "/boot" = {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
      neededForBoot = true;
    };
  };

  environment.persistence."/persist" = {
    enable = true;
    hideMounts = true;
    directories = [
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
  };

  # Services
  services = {
    openssh.enable = true;

    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };

    qemuGuest.enable = true;
  };

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
    extraGroups = [ "wheel" "networkmanager" ];
    hashedPassword = (import ../passwords).password;
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPTpfPoB4Z+DTvGcSrnrl/+RU0GULGScqvls4T0AW6is"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINvjpybr/+VM1dY75+BkISNz3hzwheDMsr9wiN5Dtsdz"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJH8z+mQ3H3qiMYCAr5qjxS+OTnZPU18D9bSdLfTvG4/98Vv2pqekGGLZ6sjeDqjtENtx5MWL1q2DPd95a5ng0g="
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGpHFZG50jXUnHmtix5s2TjAuxaUNJXDmtxXIFd9VBGv"
    ];
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

  # Basic system packages
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
  ];

  programs = {
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    # Enable fish shell system-wide
    fish.enable = true;
  };

  # Enable ZFS services
  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
  };

  # System Version
  system.stateVersion = "24.11";
}
