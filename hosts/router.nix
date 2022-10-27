{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../services/ssh-secure.nix
  ];

  boot = {
    initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "sr_mod" "virtio_blk" ];
    initrd.kernelModules = [ ];
    kernelModules = [ ];
    extraModulePackages = [ ];
    kernelParams = [ "bnx2x.mask_tx_fault=3" ];

    kernelPackages = let
      linux_custom_pkg = { fetchFromGitHub, buildLinux, ... } @ args:

        buildLinux (args // rec {
          version = "5.15.74";
          modDirVersion = version;

          src = fetchFromGitHub {
	    owner = "asdrubalini";
	    repo = "linux-bnx2x";
	    rev = "txfault";
	    sha256 = "sha256-vKExF1TwQIjWOXTJAt0xUsL/gUA+CNJCYZVScRIMD64=";
          };
	  kernelPatches = [];

        } // (args.argsOverride or {}));

      linux_custom = pkgs.callPackage linux_custom_pkg {};
    in
      pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor linux_custom);

    kernel.sysctl = {
      # if you use ipv4, this is all you need
      "net.ipv4.conf.all.forwarding" = true;

      # If you want to use it for ipv6
      "net.ipv6.conf.all.forwarding" = true;

      # source: https://github.com/mdlayher/homelab/blob/master/nixos/routnerr-2/configuration.nix#L52
      # By default, not automatically configure any IPv6 addresses.
      "net.ipv6.conf.all.accept_ra" = 0;
      "net.ipv6.conf.all.autoconf" = 0;
      "net.ipv6.conf.all.use_tempaddr" = 0;

      # On WAN, allow IPv6 autoconfiguration and tempory address use.
      "net.ipv6.conf.${name}.accept_ra" = 2;
      "net.ipv6.conf.${name}.autoconf" = 1;
    };
  };

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/a00746d8-02d2-4b0b-8226-3745c33918c8";
      fsType = "btrfs";
      options = [ "subvol=@" ];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/a00746d8-02d2-4b0b-8226-3745c33918c8";
      fsType = "btrfs";
      options = [ "subvol=@home" ];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/a00746d8-02d2-4b0b-8226-3745c33918c8";
      fsType = "btrfs";
      options = [ "subvol=@nix" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/6CAD-375A";
      fsType = "vfat";
    };

  swapDevices = [ ];

  networking = {
    vlans = {
      wan = {
        id = 10;
        interface = "enp1s0f0";
      };

      lan = {
        id = 20;
        interface = "enp1s0f1";
      };

      virtual = {
        id = 30;
        interface = "enp6s18";
      };
    };

    interfaces = {
      enp1s0f0.useDHCP = false;
      enp1s0f1.useDHCP = false;
      enp6s18.useDHCP = false;

      # fibre
      # enp1s0f0 = {
      # };

      #ipv4.addresses = [ {
      #  address = "192.168.1.1";
      #  prefixLength = 24;
      #} ];

      wan = {
        useDHCP = true;
        macAddress = "00:11:22:aa:bb:cc";
      };

      lan = {
        ipv4.addresses = [ {
          address = "10.0.0.1";
          prefixLength = 20;
        } ];
      };

      virtual = {
        useDHCP = true;
      };
    };

    dhcpcd.persistent = true;
    dhcpcd.extraConfig = ''
      send vendor-class-identifier "Technicolor_DGA4131FWB/dslforum.org";
    '';

    defaultGateway = "10.0.0.200";
    nameservers = [ "10.0.0.3" ];
  };

  services.pppd = {
    enable = true;
    peers = {
      edpnet = {
        # Autostart the PPPoE session on boot
        autostart = true;
        enable = true;
        config = ''
          plugin rp-pppoe.so wan
          
          # pppd supports multiple ways of entering credentials,
          # this is just 1 way
          name "0264087024@alicebiz.routed"
          password "timadsl"

          persist
          maxfail 0
          holdoff 5

          noipdefault
          defaultroute
        '';
      };
    };
  };

  hardware.cpu.intel.updateMicrocode = config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;

  hardware.firmware = with pkgs; [ linux-firmware ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nixpkgs.config.allowUnfree = true;
  networking.hostName = "router";
  time.timeZone = "Europe/Rome";

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    packages = with pkgs; [ terminus_font ];
  };

  users = {
    mutableUsers = false;
    extraUsers.root.hashedPassword = (import ../passwords).password;

    users.giovanni = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPassword = (import ../passwords).password;
    };
  };

  environment.systemPackages = with pkgs; [
    ethtool conntrack-tools
  ];

  programs.neovim.enable = true;
  programs.neovim.viAlias = true;
  programs.fish.enable = true;

  services.iperf3 = {
    enable = true;
    openFirewall = true;
    verbose = true;
  };

  services.caddy = {
    enable = true;
    virtualHosts."10.0.0.1".extraConfig = ''
      reverse_proxy http://192.168.1.10
    '';
  };

  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  users.users."giovanni".openssh.authorizedKeys.keys =
    [
      (import ../ssh-keys/the-hydra.nix).key
      (import ../ssh-keys/proxmox.nix).key
    ];
  
  networking.firewall.allowedTCPPorts = [ 8000 80 443 ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  system.stateVersion = "22.05";
}
