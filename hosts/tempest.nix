{
  pkgs,
  inputs,
  lib,
  ...
}:

{
  imports = [
    ../rices/hypr/fonts.nix

    # ../hardware/rocm.nix
    ../hardware/bluetooth.nix
    ../hardware/audio.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_6_14;

  networking.hostName = "tempest"; # Define your hostname.
  networking.hostId = "856ff057";

  boot.initrd.kernelModules = [ "btrfs" ];
  boot.initrd.supportedFilesystems = [
    "btrfs"
    "vfat"
  ];

  fileSystems."/" = {
    fsType = "tmpfs";
    options = [
      "defaults"
      "size=4G"
      "mode=755"
    ];
  };

  # Configure Bootloader (GRUB for LUKS unlock)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # Hibernation
  # powerManagement.resumeDevice = "/dev/mapper/cryptswap";

  time.timeZone = "Europe/Rome";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    packages = with pkgs; [ terminus_font ];
    keyMap = "us";
  };

  users.users.irene = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPassword = "$6$BkMgWYEIITYDhZkR$KnfSasOiuqi14e.85Ft/YMjgxoniRxoYXc8Tbk1J4ksq2I8Hk358V2OQFcRqHmBv/g52nhCOUWvb3uzjQuMbF0";
  };

  security.doas = {
    enable = true;
    wheelNeedsPassword = false;
  };
  security.sudo.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  environment.systemPackages = with pkgs; [
    neovim
    curl
    git
  ];

  nix = {
    package = pkgs.nixVersions.stable;
    settings.trusted-users = [
      "root"
      "irene"
    ];
    settings = {
      substituters = [ "https://hyprland.cachix.org" ];
      trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
    };
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  programs.dconf.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        # Encoding/decoding acceleration
        libvdpau-va-gl
        libva-vdpau-driver
        libva
      ];
    };
  };

  services = {
    fwupd = {
      enable = true;
      extraRemotes = [ "lvfs-testing" ]; # Some framework firmware is still in testing
    };

    logind.lidSwitch = "suspend-then-hibernate";
    power-profiles-daemon.enable = true;
  };

  powerManagement = {
    cpuFreqGovernor = lib.mkDefault "powersave";
    powertop.enable = true; # Run powertop on boot
  };

  # === User configs ===
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  };

  programs.fish.enable = true;
  programs.mosh.enable = true;

  system.stateVersion = "24.11";
}
