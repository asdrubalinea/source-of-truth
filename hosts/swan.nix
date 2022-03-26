{ config, pkgs, ... }:

{
  imports =
    [
      ../hardware/radeon.nix
      ../hardware/nvidia-prime.nix

      ../desktop/sway.nix
      ../desktop/fonts.nix
      ../desktop/pipewire.nix

      ../scripts/brightness.nix

      ../services/redshift.nix

      ../network/hosts.nix
    ];

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_zen;
  };

  networking.hostName = "swan"; # Define your hostname.
  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.wireless.userControlled.enable = true;
  networking.networkmanager.enable = false;

  # Set your time zone.
  time.timeZone = "Europe/Rome";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;
  networking.interfaces.wlp4s0.useDHCP = true;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "it";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.giovanni = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    # Passwords
    keepassxc

    # Social
    tdesktop

    # Terminals
    alacritty

    # System utils
    wget curl git sudo neofetch htop dstat
    barrier glxinfo sshfs
    pavucontrol pciutils
    gparted

    # Browsers
    firefox ungoogled-chromium
    
    # Rust
    rustup

    # Python
    python310

    # IDEs
    vscode emacs neovim

    # Docker
    docker-compose

    # Multimedia
    mpv
  ];

  virtualisation.docker.enable = true;

  # networking.firewall.allowedTCPPorts = [ ...];
  # networking.firewall.allowedUDPPorts = [ ... ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}
