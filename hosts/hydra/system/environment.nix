{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    helix
    openssh
    tailscale
  ];

  environment.variables = {
    EDITOR = "${pkgs.helix}/bin/hx";
  };
}
