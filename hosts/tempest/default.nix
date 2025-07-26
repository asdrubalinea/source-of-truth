{ pkgs, ... }:

let
  # its a secret
  hashedPassword = "$6$BkMgWYEIITYDhZkR$KnfSasOiuqi14e.85Ft/YMjgxoniRxoYXc8Tbk1J4ksq2I8Hk358V2OQFcRqHmBv/g52nhCOUWvb3uzjQuMbF0";
in
{
  imports = [
    # Modular tempest-specific configuration
    ./hardware.nix
    ./boot.nix
    ./persistence.nix
    ./networking.nix
    ./virtualization.nix

    # Shared hardware modules
    ../../hardware/bluetooth.nix
    ../../hardware/audio.nix
    ../../hardware/framework.nix

    # System modules
    ../../modules/secure-boot.nix
    ../../modules/nix.nix

    # Services
    ../../services/btrfs-snapshots.nix
    ../../services/nix-cleanup.nix

    # Desktop environment
    ../../rices/estradiol/system.nix
  ];

  # System services
  services = {
    openssh.enable = true;
    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };
    gnome.gnome-keyring.enable = true;
  };

  # Localization
  time.timeZone = "Europe/Rome";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    packages = with pkgs; [ terminus_font ];
    keyMap = "us";
  };

  # User configuration
  users.users = {
    irene = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
        "docker"
      ];
      inherit hashedPassword;
      shell = pkgs.fish;
    };

    # plasma = {
    #   isNormalUser = true;
    #   extraGroups = [
    #     "wheel"
    #     "networkmanager"
    #   ];
    #   hashedPassword = "$6$BkMgWYEIITYDhZkR$KnfSasOiuqi14e.85Ft/YMjgxoniRxoYXc8Tbk1J4ksq2I8Hk358V2OQFcRqHmBv/g52nhCOUWvb3uzjQuMbF0";
    #   shell = pkgs.fish;
    # };

    # claude = {
    #   isNormalUser = true;
    #   extraGroups = [ "networkmanager" ];
    #   hashedPassword = "$6$BkMgWYEIITYDhZkR$KnfSasOiuqi14e.85Ft/YMjgxoniRxoYXc8Tbk1J4ksq2I8Hk358V2OQFcRqHmBv/g52nhCOUWvb3uzjQuMbF0";
    #   shell = pkgs.fish;
    #   home = "/home/claude";
    #   createHome = true;
    # };
  };

  # Security configuration
  security = {
    doas = {
      enable = true;
      wheelNeedsPassword = false;
    };
    sudo = {
      package = pkgs.sudo-rs;
      execWheelOnly = true;
    };
    sudo-rs.enable = true;
    pam.services.greetd.enableGnomeKeyring = true;
  };


  # System packages and programs
  environment.systemPackages = with pkgs; [
    neovim
    curl
    git
  ];

  programs = {
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    dconf.enable = true;
  };

  # System Version
  system.stateVersion = "24.11";
}
