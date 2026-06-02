{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    curl
    git
    helix
    neovim
  ];

  environment.variables = {
    EDITOR = "${pkgs.helix}/bin/hx";
  };
}
