{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/virtualisation/lxc-container.nix>
    ../network/wireguard/arrow-server.nix
  ];

  nixpkgs.config.allowUnfree = true;

  networking.hostName = "test";

  time.timeZone = "Europe/Rome";

  users = {
    mutableUsers = false;
    extraUsers.root.hashedPassword = (import ../passwords).password;

    users.giovanni = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPassword = (import ../passwords).password;
    };
  };

  security.sudo.wheelNeedsPassword = true;

  environment.systemPackages = with pkgs; [ git ];

  programs.neovim.enable = true;
  programs.neovim.viAlias = true;

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  services.nginx.enable = true;
  
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  system.stateVersion = "22.05";
}
