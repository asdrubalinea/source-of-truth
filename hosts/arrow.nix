{ config, pkgs, lib, ... }:

{
  imports = [ ../services/ssh-secure.nix ../network/hosts.nix ];

  nixpkgs.config.allowUnfree = true;
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "arrow";

  time.timeZone = "Europe/Rome";

  # networking.useDHCP = false;
  # networking.interfaces.eno1.useDHCP = true;
  # networking.interfaces.wlp4s0.useDHCP = true;

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
    };
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [ neovim git ];

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  users.users."giovanni".openssh.authorizedKeys.keys =
    [ (import ../ssh-keys/swan.nix).key ];

  # networking.firewall.allowedTCPPorts = [ ...];
  # networking.firewall.allowedUDPPorts = [ ... ];

  system.stateVersion = "22.05";
}
