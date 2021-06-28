# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  nixpkgs.config.allowUnfree = true;

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_5_11;
    extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];
  };
  
  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Set your time zone.
  time.timeZone = "Europe/Rome";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;
  # networking.interfaces.wlp4s0.useDHCP = true;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "it";
  };

  services.xserver = {
    enable = true;
    videoDrivers = [ "nvidia" ];

    displayManager.gdm.enable = true;
    desktopManager.gnome3.enable = true;

    config = ''
    Section "OutputClass"
      Identifier "AMDgpu"
      MatchDriver "amdgpu"
      Driver "amdgpu"
      Option "TearFree" "true"
    EndSection
    '';
  };

  # Configure keymap in X11
  services.xserver.layout = "it";
  services.xserver.xkbOptions = "eurosign:e";
  
  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  
  hardware = {
    opengl = {
      driSupport = true;
      driSupport32Bit = true;
    };

    nvidia = {
      prime = {
        offload.enable = true;
        amdgpuBusId = "PCI:05:0:0";
        nvidiaBusId = "PCI:01:0:0";
      };

      modesetting.enable = true;
    };
  };
  
  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.giovanni = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wget vim curl git
    sudo neofetch htop
    chromium keepassxc glxinfo
    gnome3.gnome-tweaks
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:
  # services.pipewire.alsa.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?

}
