{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    ./common.nix

    ../network/wireguard/arrow-server.nix
  ];

  nixpkgs.config.allowUnfree = true;

  networking.hostName = "test";

  time.timeZone = "Europe/Rome";

  environment.systemPackages = with pkgs; [git];

  programs.neovim.enable = true;
  programs.neovim.viAlias = true;

  nix = {
    package = pkgs.nixVersions.stable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  services.nginx.enable = true;

  networking.firewall.allowedTCPPorts = [80 443];
  # networking.firewall.allowedUDPPorts = [ ... ];

  system.stateVersion = "22.05";
}
