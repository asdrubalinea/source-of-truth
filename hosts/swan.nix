{ config, pkgs, ... }:

{
  imports =
    [
      ../hardware/radeon.nix
      ../hardware/nvidia-prime.nix

      ../desktop/sway.nix
      ../desktop/fonts.nix

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

  # Configure keymap in X11
  services.xserver.layout = "it";
  services.xserver.xkbOptions = "eurosign:e";

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

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
    wget neovim curl git sudo neofetch htop dstat
    barrier glxinfo sshfs arandr
    exa pavucontrol pciutils

    # Browsers
    firefox
    
    # Rust
    rustup

    # Python
    python310

    # IDEs
    vscode emacs

    # Docker
    docker-compose

    spotify
  ];

  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;
  users.extraGroups.vboxusers.members = [ "giovanni" ];

  virtualisation.docker.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    24800 # Barrier
  ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}
