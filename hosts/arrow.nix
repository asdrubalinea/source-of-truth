{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}: let
  limbo = pkgs.callPackage ../packages/secrets/limbo.nix {};
in {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../services/ssh-secure.nix
    ../services/secrets/limbo.nix
    ../services/secrets/the-lamp-post.nix

    ../mounts/secrets/hetzner-nas.nix

    ../network/hosts.nix
    ../network/wireguard/arrow-server.nix
  ];

  nixpkgs.config.allowUnfree = true;
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "arrow";

  time.timeZone = "Europe/Rome";

  networking.useDHCP = false;
  networking.interfaces.ens3.useDHCP = true;
  networking.interfaces.ens10.useDHCP = true;

  boot.initrd.availableKernelModules = ["ata_piix" "virtio_pci" "virtio_scsi" "xhci_pci" "sd_mod" "sr_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/6cd1d21a-1d6b-405a-b6ec-f5e204649ea7";
    fsType = "btrfs";
  };

  swapDevices = [];

  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    packages = with pkgs; [terminus_font];
    keyMap = "it";
  };

  users = {
    mutableUsers = false;
    extraUsers.root.hashedPassword = (import ../passwords).password;

    users.giovanni = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      hashedPassword = (import ../passwords).password;
    };
  };

  security.sudo.wheelNeedsPassword = true;

  environment.systemPackages = with pkgs; [git];

  programs.neovim.enable = true;
  programs.neovim.viAlias = true;

  services.limbo.enable = true;
  services.the-lamp-post.enable = true;
  services.iperf3 = {
    enable = true;
    openFirewall = true;
    verbose = true;
  };

  nix = {
    # package = pkgs.nixVersions.stable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  users.users."giovanni".openssh.authorizedKeys.keys = [
    (import ../ssh-keys/swan.nix).key
    (import ../ssh-keys/the-hydra.nix).key
    (import ../ssh-keys/router.nix).key
  ];

  networking.firewall.allowedTCPPorts = [80 443];
  # networking.firewall.allowedUDPPorts = [ ... ];

  programs.mosh.enable = true;

  nix.sshServe.enable = true;
  nix.sshServe.keys = [(import ../ssh-keys/router.nix).key];


  #services.nextcloud = {
  #  enable = true;
  #  package = pkgs.nextcloud24;
  #  hostName = "asdrubalini.xyz";
  #  https = true;
  #  config.adminpassFile = "/home/nextcloud/admin-pass";
  #};

  system.stateVersion = "22.05";
}
