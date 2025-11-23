{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../services/ssh-secure.nix
    ../modules/nix.nix
  ];

  boot = {
    initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "sr_mod" "virtio_blk" ];
    initrd.kernelModules = [ ];
    kernelModules = [ ];
    extraModulePackages = [ ];
    kernelParams = [ "bnx2x.mask_tx_fault=3" ];

    kernelPackages =
      let
        linux_custom_pkg = { fetchFromGitHub, buildLinux, ... } @ args:

          buildLinux (args // rec {
            version = "6.1.0";
            modDirVersion = version;

            src = fetchFromGitHub {
              owner = "asdrubalini";
              repo = "linux-bnx2x";
              rev = "267524a6a1908a898d8ffbf715cd2ec2cc762b41";
              sha256 = "sha256-zcdrdH5HJ+uvvXI9dffoRbQwwo0z1gZsvhIoy1ZbXjE=";
            };

            kernelPatches = [ ];
            configfile = ../kernel-configs/router.config;

          } // (args.argsOverride or { }));
        linux_custom = pkgs.callPackage linux_custom_pkg { };
      in
      pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor linux_custom);

    kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = true;
      "net.ipv6.conf.all.forwarding" = true;

      # source: https://github.com/mdlayher/homelab/blob/master/nixos/routnerr-2/configuration.nix#L52
      # By default, not automatically configure any IPv6 addresses.
      "net.ipv6.conf.all.accept_ra" = 0;
      "net.ipv6.conf.all.autoconf" = 0;
      "net.ipv6.conf.all.use_tempaddr" = 0;

      # On WAN, allow IPv6 autoconfiguration and tempory address use.
      "net.ipv6.conf.wan.accept_ra" = 2;
      "net.ipv6.conf.wan.autoconf" = 1;
    };
  };

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/a00746d8-02d2-4b0b-8226-3745c33918c8";
      fsType = "btrfs";
      options = [ "subvol=@" ];
    };

  fileSystems."/home" =
    {
      device = "/dev/disk/by-uuid/a00746d8-02d2-4b0b-8226-3745c33918c8";
      fsType = "btrfs";
      options = [ "subvol=@home" ];
    };

  fileSystems."/nix" =
    {
      device = "/dev/disk/by-uuid/a00746d8-02d2-4b0b-8226-3745c33918c8";
      fsType = "btrfs";
      options = [ "subvol=@nix" ];
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/6CAD-375A";
      fsType = "vfat";
    };

  swapDevices = [ ];

  networking = {
    useDHCP = false;
    nat.enable = false;
    firewall.enable = false;

    nftables = {
      enable = true;
      ruleset = ''
        table inet filter {
          chain output {
            type filter hook output priority 100; policy accept;
          }

          chain input {
            type filter hook input priority filter; policy drop;

            # Allow 6to4
            ip protocol 41 ip saddr 216.66.80.98 accept;

            tcp dport ssh accept;

            # Allow trusted networks to access the router
            iifname { "lan", } counter accept

            # Allow returning traffic from ppp0 and drop everthing else
            iifname "ppp0" ct state { established, related } counter accept
            iifname "ppp0" drop
          }

          chain forward {
            type filter hook forward priority filter; policy drop;
            tcp flags syn tcp option maxseg size set 1452;

            # Allow trusted network WAN access
            iifname { "lan", } oifname { "ppp0", } counter accept comment "Allow trusted LAN to WAN"

            # Allow established WAN to return
            iifname { "ppp0", } oifname { "lan", } ct state established,related counter accept comment "Allow established back to LANs"
          }
        }

        table ip nat {
          chain prerouting {
            type nat hook output priority filter; policy accept;
          }

          # Setup NAT masquerading on the ppp0 interface
          chain postrouting {
            type nat hook postrouting priority filter; policy accept;
            oifname "ppp0" masquerade
          }
        }
      '';
    };

    vlans = {
      wan = { id = 835; interface = "enp1s0f0"; };
    };

    bridges = {
      "lan" = { interfaces = [ "enp1s0f1" "enp6s18" ]; };
    };

    interfaces = {
      enp1s0f0 = {
        macAddress = "00:11:22:aa:bb:cc";
        useDHCP = false;
        # ipv4.addresses = [ { address = "192.168.1.1"; prefixLength = 24; } ];
      };

      wan = {
        macAddress = "00:11:22:aa:bb:cc";
        useDHCP = true;
      };

      # Lan
      lan = {
        ipv4.addresses = [{
          address = "10.0.0.1";
          prefixLength = 20;
        }];
      };

      enp6s18 = {
        useDHCP = false;
      };

      enp1s0f1 = {
        useDHCP = false;
      };
    };

    dhcpcd = {
      persistent = true;
      allowInterfaces = [ "wan" ];
      extraConfig = ''
        send vendor-class-identifier "Technicolor_DGA4131FWB/dslforum.org";
      '';
    };

    nameservers = [ "1.1.1.1" ];
    # defaultGateway = "10.0.0.200";
  };

  services.pppd = {
    enable = true;
    peers = {
      tim = {
        # Autostart the PPPoE session on boot
        autostart = true;
        enable = true;
        config = ''
          	  plugin pppoe.so

                    wan

                    name "0264087024@alicebiz.routed"
                    password "timadsl"

                    persist
                    maxfail 0
                    holdoff 5

                    defaultroute
                    replacedefaultroute
        '';
      };
    };
  };

  services.dhcpd4 = {
    enable = true;
    interfaces = [ "lan" ];

    extraConfig = ''
      option subnet-mask 255.255.240.0;
      option broadcast-address 10.0.15.254;
      option routers 10.0.0.1;
      option domain-name-servers 10.0.0.3;

      subnet 10.0.0.0 netmask 255.255.240.0 {
        range 10.0.2.0 10.0.3.255;
      }
    '';
  };

  hardware.cpu.intel.updateMicrocode = config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;

  hardware.firmware = with pkgs; [ linux-firmware ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;


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

    users.irene = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPassword = (import ../passwords).password;
    };
  };

  environment.systemPackages = with pkgs; [
    ethtool
    conntrack-tools
    ppp
    rpPPPoE # not used maybe
    sshuttle
    python3
  ];

  programs.neovim.enable = true;
  programs.neovim.viAlias = true;
  programs.fish.enable = true;

  services.iperf3 = {
    enable = true;
    openFirewall = true;
    verbose = true;
  };

  services.qemuGuest.enable = true;
  programs.mosh.enable = true;

  users.users."irene".openssh.authorizedKeys.keys =
    [
      (import ../ssh-keys/the-hydra.nix).key
      (import ../ssh-keys/proxmox.nix).key
      (import ../ssh-keys/ipad.nix).key
    ];

  system.stateVersion = "22.05";
}
