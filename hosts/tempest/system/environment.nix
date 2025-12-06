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

  programs = {
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    dconf.enable = true;
  };
}
