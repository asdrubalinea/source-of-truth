# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  networking.hostName = "nixos"; # Define your hostname.

  # Set your time zone.
  time.timeZone = "Europe/Rome";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.enp0s8.useDHCP = true;
  networking.interfaces.enp0s17.useDHCP = true;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "it";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.giovanni = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC4d2KMYBCOl55p3LiygNNVpk+gXCkqq8HLKkfOY9YX2JH2XHP98iureac69086YTL0dWUE/MFm2Jv5020j0QNQQ4ww4oJWa5c1YDYG/NJU+NTad/R5IJGxEcYXCnB0nhL6s6P/eFwBr0G0pQymf6LADc6zg9kzH+a+ijA/MgKfp2N59qUSi0dUZaa8goEedpTI/lEmNZRGV9wQN4GYsw0ucFe+sDF1DCRrXh6n05PSmWaW55GT8uJLPyAEiagY1EQ55zTTb61GGAqlS+931Q/XtLAKuRPS8ilrxJ+4QpxV7Qtsrm+Q2OMy04DbPXHM4S0uJg4AOPSgPy3o9sZh8zGDqIY37cSKbRMsXJVsi8c3SEy7xZLHi4LJIIr6yYM+qNqAKDJksHWGVQw2+iNMNqoVj3030wBHL6wxiPa4qzBCCZJhSSLIp0M/u7p6++u5Q8lqW9xjYC6Y4xQlEQoFUNXHzUsx3eXekZl9XIHA482XbjzjERVye5hFiOvyoV7Eov4lym4ec0CU6XgzasZ/gJpZ1dSvmdavzvRNQ8h9aWIT8z2L6/Z6MzQuL35AXmA1z0H1/IoOy+oyj3Yb7lN6YiTeD83n4lg11FF6M69BV3Wnh6OEn83NOaRQhC7c1m/5hS3jWcm35+u1g7us3as1fxCgPosB+zTYnMj6+c+SH6Hn7w== giovanni@lenovo" ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [ vim htop git ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    passwordAuthentication = false;
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 ];
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

