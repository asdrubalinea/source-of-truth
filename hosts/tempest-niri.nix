{ pkgs
, lib
, config
, ...
}:

{
  imports = [
    ../hardware/bluetooth.nix
    ../hardware/audio.nix
    ../hardware/framework.nix
    ../modules/secure-boot.nix
    ../modules/nix.nix
    # ../desktop/gnome.nix
    ../desktop/plasma.nix

    ../rices/niri/system.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Boot Configuration
  boot = {
    # kernelPackages = pkgs.trunk.linuxPackages_6_14;
    kernelPackages = pkgs.linuxPackages_6_15;
    kernelPatches = [
      # {
      # name = "0001_dpg_pause_unpause_for_vcn_4_0_5";
      # patch = ../patches/0001_dpg_pause_unpause_for_vcn_4_0_5.patch;
      # }

      # {
      #name = "0001-turn-off-doorbell-for-vcn-ring-use";
      #patch = ../patches/0001-turn-off-doorbell-for-vcn-ring-use.patch;
      #}
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
    # useDHCP = true;
  };

  # Use systemd-resolved for NextDNS with DNS-over-TLS
  services.resolved = {
    enable = true;
    dnssec = "true";
    domains = [ "~." ];
    fallbackDns = [ "1.1.1.1" "1.0.0.1" ];
    extraConfig = ''
      DNS=45.90.28.0#3e5f5a.dns.nextdns.io
      DNS=2a07:a8c0::#3e5f5a.dns.nextdns.io
      DNS=45.90.30.0#3e5f5a.dns.nextdns.io
      DNS=2a07:a8c1::#3e5f5a.dns.nextdns.io
      DNSOverTLS=yes
    '';
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
      "/var/lib/sddm"
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

    gnome.gnome-keyring.enable = true;
  };

  # Power Management
  #powerManagement = {
  # cpuFreqGovernor = lib.mkDefault "powersave";
  # powertop.enable = true;
  # };

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

  users.users.plasma = {
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
    sudo = {
      package = pkgs.sudo-rs;
      execWheelOnly = true;
    };
    sudo-rs.enable = true;
    pam.services.greetd.enableGnomeKeyring = true;
  };

  # Nix Configuration
  # Override shared Nix config to add niri-specific cache
  nix.settings = {
    substituters = [
      "https://cache.nixos.org/"
      "https://hyprland.cachix.org"
      "https://cosmic.cachix.org/"
      "https://niri.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
    ];
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
  };

  networking.extraHosts = ''
    127.0.0.1 dscovr.test
    127.0.0.1 tak.dscovr.test
    127.0.0.1 admin.dscovr.test
    127.0.0.1 app.dscovr.test
    127.0.0.1 experiment.dscovr.test
    127.0.0.1 teams.dscovr.test
    127.0.0.1 acea.dscovr.test
    127.0.0.1 workspace5nrt.dscovr.test
    127.0.0.1 workspace0tcb.dscovr.test
    127.0.0.1 workspace2nrt.dscovr.test
    127.0.0.1 workspace5nrt.dscovr.test
  '';

  hardware.logitech.wireless.enable = true;

  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [ "irene" ];
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  # System Version
  system.stateVersion = "24.11";
}
