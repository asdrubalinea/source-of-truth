# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    ../../scripts/system-clean.nix
    ../../scripts/system-upgrade.nix

    ../../hardware/nvidia.nix

    ../../desktop/x11.nix
    ../../desktop/pipewire.nix
    ../../desktop/fonts.nix
    ../../desktop/dwm.nix

    ../../network/hosts.nix

    ../../misc/bash-aliases.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };
  
  networking.hostName = "looking-glass"; # Define your hostname.
  networking.networkmanager.enable = false;

  # Set your time zone.
  time.timeZone = "Europe/Rome";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.enp3s0.useDHCP = false;

  networking.interfaces.enp3s0.ipv4.addresses = [ {
    address = "10.0.0.16";
    prefixLength = 24;
  } ];
  networking.defaultGateway = "10.0.0.1";
  networking.nameservers = [ "1.1.1.1" ];


  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Configure keymap in X11
  services.xserver.layout = "us";
  
  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.giovanni = {
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "video" "sound" ];
    openssh.authorizedKeys.keys = [
      (import ../../ssh-keys/lenovo.nix).lenovoKey
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Passwords
    keepassxc

    # Network
    openvpn

    # Social
    tdesktop

    # Terminals
    alacritty

    # System utils
    wget neovim curl git sudo neofetch htop dstat
    barrier glxinfo sshfs arandr
    exa pavucontrol fish

    # Browsers
    firefox brave

    # Python
    python310
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    passwordAuthentication = false;
  };

  networking.firewall.allowedTCPPorts = [ 22 24800 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  networking.firewall.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?

}
