{ inputs, lib, pkgs, ... }: {
  imports = [
    ../rices/hypr/fonts.nix

    # ../options/passthrough.nix
    ../hardware/rocm.nix
    ../hardware/bluetooth.nix
    ../hardware/zfs.nix
    ../hardware/audio.nix

    ../services/syncthing.nix
  ];

  # vfio.enable = false;

  #specialisation."VFIO".configuration = {
  #  system.nixos.tags = [ "with-vfio" ];
  #vfio.enable = true;
  #};

  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["irene"];
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  boot.initrd.availableKernelModules = ["ahci" "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd" "amdgpu"];
  boot.extraModulePackages = [];

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableAllFirmware = true;

  services.flatpak.enable = true;

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

  networking.hostName = "orchid";
  networking.hostId = "f00dbabe";

  # Upstream internet
  networking.interfaces.enp4s0f0.ipv4.addresses = [ {
    address = "10.0.0.10";
    prefixLength = 20;
  } ];

  # Erase your darlings.
  # systemd.tmpfiles.rules = [
  # "L /var/lib/tailscale - - - - /persist/var/lib/tailscale"
  # ];

  networking.defaultGateway = "10.0.0.1";
  networking.nameservers = ["1.1.1.1" "1.0.0.1"];
  networking.useDHCP = false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  boot.kernelParams = [
    "zfs.zfs_arc_max=51539607552" # 48 GiB
    "nohibernate"
  ];

  # Enable nested virtualization
  boot.extraModprobeConfig = ''
    options kvm_amd nested=1
  '';

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
  };

  time.timeZone = "Europe/Rome";

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

    users."irene" = {
      isNormalUser = true;
      extraGroups = ["wheel" "libvirtd" "docker" "jackaudio" "render" "video"];
      openssh.authorizedKeys.keys = [(import ../ssh-keys/looking-glass.nix).key];
      hashedPassword = (import ../passwords).password;
      shell = pkgs.fish;
    };
  };

  security.sudo.enable = true;
  security.doas.enable = true;

  security.doas.extraRules = [{
    users = ["irene"];
    keepEnv = true;
    noPass = true;
  }];

  environment.systemPackages = with pkgs; [
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

  services.github-runners = {
    leksi = {
      enable = true;
      name = "leksi";
      tokenFile = "/persist/secrets/github-runners/leksi";
      url = "https://github.com/asdrubalinea/leksi";
    };
  };

  virtualisation.docker = {
    enable = true;
    extraOptions = "--data-root=/mnt/docker";
  };

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

  # networking.firewall.allowedTCPPorts = [ ];
  # networking.firewall.allowedUDPPorts = [ ];

  system.stateVersion = "23.05";
}
