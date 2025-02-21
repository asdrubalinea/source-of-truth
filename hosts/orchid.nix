{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../network/hosts.nix
    ../rices/hypr/fonts.nix

    # ../options/passthrough.nix
    ../hardware/rocm.nix
    # ../services/syncthing.nix
  ];

  boot.initrd.availableKernelModules = ["ahci" "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd" "amdgpu"];
  boot.extraModulePackages = [];

  # vfio.enable = false;

  #specialisation."VFIO".configuration = {
  #  system.nixos.tags = [ "with-vfio" ];
  #vfio.enable = true;
  #};

  # services.sdrplayApi.enable = true;

  nix.gc = {
		automatic = true;
		dates = "weekly";
		options = "--delete-older-than 30d";
	};

  fileSystems."/" = {
    device = "zroot/local/root";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/726C-CCD8";
    fsType = "vfat";
  };

  fileSystems."/nix" = {
    device = "zroot/local/nix";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "zroot/safe/home";
    fsType = "zfs";
  };

  fileSystems."/persist" = {
    device = "zroot/safe/persist";
    fsType = "zfs";
  };

  fileSystems."/mnt/docker" = {
    device = "zroot/local/docker";
    fsType = "zfs";
  };

  fileSystems."/data" = {
    device = "rpool/data";
    fsType = "zfs";
  };

  swapDevices = [];

  networking.hostName = "orchid"; # Define your hostname.
  networking.hostId = "f00dbabe";

  # Upstream internet
  networking.interfaces.enp4s0f0.ipv4.addresses = [
    {
      address = "10.0.0.10";
      prefixLength = 20;
    }
  ];

  # Erase your darlings.
  # systemd.tmpfiles.rules = [
  # "L /var/lib/tailscale - - - - /persist/var/lib/tailscale"
  # ];

  # networking.interfaces.enp14s0.ipv4.addresses = [ {
  # address = "10.0.0.11";
  # prefixLength = 20;
  # } ];

  # networking.defaultGateway = "10.0.0.1";
  networking.defaultGateway = "10.0.0.1";
  networking.nameservers = ["1.1.1.1" "1.0.0.1"];
  networking.useDHCP = false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  boot.zfs = {
    package = pkgs.zfs_unstable;
    forceImportAll = false;
  };

  boot.kernelParams = [
    "zfs.zfs_arc_max=51539607552" # 48 GiB
    "nohibernate"
  ];

  boot.supportedFilesystems = ["zfs"];

  # Enable nested virtualization
  boot.extraModprobeConfig = ''
    options kvm_amd nested=1
  '';

  services.zfs.autoScrub = {
    enable = true;
    interval = "Sun, 01:00";
  };

  services.zfs.autoSnapshot.enable = true;

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableAllFirmware = true;

  programs.steam = {
    enable = false;
    # remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    # dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      grub = {
        copyKernels = true; # For better ZFS compatibility
        enableCryptodisk = true;
        configurationLimit = 16;
      };
    };

    loader.efi.canTouchEfiVariables = true;
    # kernelPackages = pkgs.linuxPackages_6_11;
  };

  # Erase your darlings.
  # boot.initrd.postDeviceCommands = lib.mkAfter ''
  # zfs rollback -r zroot/local/root@blank
  # '';

  # Enable SMART daemon
  services.smartd = {
    enable = true;
    notifications = {
      # Enable mail notifications
      mail = {
        enable = true;
        sender = "smartd@localhost";
        recipient = "smart@asdrubalini.xyz";
      };
      # Optionally enable wall notifications
      wall.enable = true;
    };
    defaults.monitored = "-a -o on -S on -T permissive";
    devices = [
      { device = "/dev/nvme0n1"; }
      { device = "/dev/nvme1n1"; }
      { device = "/dev/nvme2n1"; }
    ];
  };

  time.timeZone = "Europe/Rome";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    packages = with pkgs; [terminus_font];
    keyMap = "us";
  };

  users = {
    mutableUsers = false;
    extraUsers.root.hashedPassword = (import ../passwords).password;

    users.irene = {
      isNormalUser = true;
      extraGroups = ["wheel" "libvirtd" "docker" "jackaudio" "render" "video"];
      hashedPassword = (import ../passwords).password;
      shell = pkgs.fish;
    };
  };

  security.sudo.enable = true;
  security.doas.enable = true;

  security.doas.extraRules = [
    {
      users = ["irene"];
      keepEnv = true;
      noPass = true;
    }
  ];

  services.postfix = {
    enable = true;
    setSendmail = true;
  };

  environment.systemPackages = with pkgs; [
    zfs
    neovim
    git
    swtpm
    tpm2-tools
    git-crypt
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

  services.ollama = {
    enable = false;
    host = "0.0.0.0";
    acceleration = "rocm";
    rocmOverrideGfx = "10.3.1";
    openFirewall = true;
  };

  services.openssh.enable = true;
  # services.openssh.settings.X11Forwarding = true;

  services.github-runners = {
    leksi = {
      enable = true;
      name = "leksi";
      tokenFile = "/persist/secrets/github-runners/leksi";
      url = "https://github.com/asdrubalini/leksi";
    };
  };

  virtualisation.docker = {
    enable = true;
    extraOptions = "--data-root=/mnt/docker";
  };

  users.users."irene".openssh.authorizedKeys.keys = [(import ../ssh-keys/looking-glass.nix).key];

  # security.polkit.enable = true;

  nix = {
    package = pkgs.nixVersions.stable;
    settings.trusted-users = ["root" "irene"];
    settings = {
      substituters = ["https://hyprland.cachix.org"];
      trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
    };
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  };

  # security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.blueman.enable = true;

  # services.keyd = {
  #   enable = true;
  #   keyboards = {
  #     # The name is just the name of the configuration file, it does not really matter
  #     default = {
  #       ids = [ "*" ]; # what goes into the [id] section, here we select all keyboards

  #       settings = {
  #         # The main layer, if you choose to declare it in Nix
  #         main = {
  #           leftcontrol = "leftmeta";
  #           leftmeta = "leftcontrol";
  #         };
  #       };
  #     };
  #   };
  # };

  networking.firewall.allowedTCPPorts = [25565 7777 ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  system.stateVersion = "23.05";
}
