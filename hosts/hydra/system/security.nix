{ pkgs, ... }:
{
  security = {
    sudo = {
      package = pkgs.sudo-rs;
      execWheelOnly = true;
      wheelNeedsPassword = false;
    };

    sudo-rs.enable = true;
  };
}
