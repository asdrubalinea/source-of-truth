{ config, pkgs, lib, ... }:

{
  imports = [
    ../hardware/radeon.nix
    ../hardware/nvidia-prime.nix
    ../hardware/pipewire.nix
    ../desktop/fonts.nix
    ../desktop/gnome.nix

    ../services/borg-backup.nix

    ../network/hosts.nix
    ../network/wireguard/swan-client.nix
  ];

  # Hardware
  boot.initrd.availableKernelModules =
    [ "xhci_pci" "nvme" "ahci" "uas" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.zfs = {
    enableUnstable = true;
    forceImportAll = false;
  };
  boot.kernelParams = [
    "zfs.zfs_arc_max=1073741824" # 1 GiB
    "nohibernate"
  ];

  boot.supportedFilesystems = [ "zfs" ];

  # Enable nested virtualization
  boot.extraModprobeConfig = "options kvm_amd nested=1";

  fileSystems."/" = {
    device = "rpool/local/root";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/8977-F6B5";
    fsType = "vfat";
  };

  fileSystems."/nix" = {
    device = "rpool/local/nix";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "data0/safe/home";
    fsType = "zfs";
  };

  fileSystems."/persist" = {
    device = "data0/safe/persist";
    fsType = "zfs";
  };

  fileSystems."/mnt/docker" = {
    device = "rpool/local/docker";
    fsType = "zfs";
  };

  fileSystems."/var/lib/libvirt" = {
    device = "rpool/local/libvirt";
    fsType = "zfs";
  };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/cda0c9ea-4923-40dd-87b1-f17e712df3f7"; }];

  services.zfs.autoScrub = {
    enable = true;
    interval = "Sun, 01:00";
  };

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableAllFirmware = true;

  nixpkgs.config.allowUnfree = true;

  boot = {
    loader = {
      systemd-boot.enable = true;
      grub = {
        copyKernels = true; # For better ZFS compatibility
        enableCryptodisk = true;
      };
    };
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_zen;
  };

  networking.hostName = "swan";
  networking.wireless.enable = true;
  networking.wireless.userControlled.enable = true;
  networking.networkmanager.enable = false;
  networking.hostId = "ea0b4bc7";

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    package = pkgs.stable.bluez;
  };
  services.blueman.enable = true;

  # Ignore power button
  services.logind.extraConfig = ''
    HandlePowerKey=ignore
  '';

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

  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;
  networking.interfaces.wlp4s0.useDHCP = true;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    packages = with pkgs; [ terminus_font ];
    keyMap = "it";
  };

  users = {
    mutableUsers = false;
    extraUsers.root.hashedPassword = (import ../passwords).password;

    users.giovanni = {
      isNormalUser = true;
      extraGroups = [ "wheel" "libvirtd" "docker" ];
      hashedPassword = (import ../passwords).password;
      shell = pkgs.fish;
    };
  };

  security.sudo.enable = true;
  security.doas.enable = true;

  security.doas.extraRules = [{
    users = [ "giovanni" ];
    keepEnv = true;
    noPass = true;
  }];

  environment.systemPackages = with pkgs; [
    polkit_gnome
    zfs
    neovim
    git
    swtpm
    git-crypt
  ];

  virtualisation.docker = {
    enable = true;
    extraOptions = "--data-root=/mnt/docker";
  };

  #virtualisation.virtualbox.host.enable = true;
  #users.extraGroups.vboxusers.members = [ "giovanni" ];
  #virtualisation.virtualbox.host.enableExtensionPack = true;

  virtualisation.spiceUSBRedirection.enable = true;

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      swtpm.enable = true;
      ovmf.enable = true;
      ovmf.package = pkgs.OVMFFull;
    };
  };

  environment.sessionVariables.VAGRANT_DEFAULT_PROVIDER = [ "libvirt" ];
  environment.sessionVariables.LIBVIRT_DEFAULT_URI = [ "qemu:///system" ];

  # services.tlp.enable = true;

  services.sdrplayApi.enable = true;

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # Polkit
  security.polkit.enable = true;

  services.borg-backup = {
    enable = true;
    name = "swan";

    repo = "ssh://u298408@u298408.your-storagebox.de:23/./backups/swan";
    ssh_key_file = "/persist/borg/ssh_key";
    password_file = "/persist/borg/passphrase";
  };

  services.dbus.enable = true;
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    # extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    gtkUsePortal = true;
  };

  #services.xserver.enable = true;
  #services.xserver.desktopManager.plasma5.enable = true;
  #services.xserver.displayManager = {
  #lightdm.enable = true;
  #sessionPackages = with pkgs; [ sway ];
  #};

  users.users."giovanni".openssh.authorizedKeys.keys =
    [ (import ../ssh-keys/looking-glass.nix).key ];

  programs.steam.enable = true;

  networking.firewall.allowedTCPPorts = [ 8000 ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  system.stateVersion = "22.05";
}
