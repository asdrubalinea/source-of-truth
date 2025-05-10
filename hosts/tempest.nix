{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:

{
  imports = [
    ../rices/hypr/fonts.nix
    ../hardware/bluetooth.nix
    ../hardware/audio.nix
    ../modules/secure-boot.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Boot Configuration
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelPatches = [
      {
        name = "0001_dpg_pause_unpause_for_vcn_4_0_5";
        patch = ../patches/0001_dpg_pause_unpause_for_vcn_4_0_5.patch;
      }
    ];

    # kernelPackages = pkgs.linuxPackages_testing;
    resumeDevice = "/dev/mapper/pool-swap";
    # kernelParams = [ "usbcore.autosuspend=-1" ];
    kernelParams = [
      "microcode.amd_sha_check=off"
      "amdgpu.dcdebugmask=0x12"
    ];

    kernelModules = [ "kvm-amd" ];

    initrd = {
      systemd.enable = true;

      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "thunderbolt"
        "usbhid"
      ];

      kernelModules = [
        "dm-snapshot"
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
        "size=32G"
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
  services.ucodenix.enable = true;
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

  # Services
  services = {
    openssh.enable = true;

    fwupd = {
      enable = true;
      extraRemotes = [ "lvfs-testing" ];
    };

    power-profiles-daemon.enable = true;

    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };

    xserver.videoDrivers = [ "amdgpu" ];

    logind.lidSwitch = "suspend-then-hibernate";
    logind.lidSwitchExternalPower = "ignore";
    logind.extraConfig = ''
      HandlePowerKey=hibernate
      HandleLidSwitchDocked=ignore
    '';
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
      substituters = [
        "https://hyprland.cachix.org"
        "https://cosmic.cachix.org/"
      ];
      trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      ];
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

  systemd.services.disable-fingerprint-led = {
    description = "Disable Framework Laptop Fingerprint LED at boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      ExecStart = "${pkgs.fw-ectool}/bin/ectool led power off";
    };
  };

  # System Version
  system.stateVersion = "24.11";
}
