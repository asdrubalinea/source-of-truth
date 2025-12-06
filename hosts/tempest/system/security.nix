{ pkgs, ... }:
{
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
}
