{ pkgs, ... }:
{
  security = {
    doas = {
      enable = true;
      wheelNeedsPassword = false;

      extraRules = [
        {
          users = [ "irene" ];
          keepEnv = true;
          noPass = true;
        }
      ];
    };

    sudo = {
      package = pkgs.sudo-rs;
      execWheelOnly = true;
      wheelNeedsPassword = false;
    };

    sudo-rs.enable = true;
  };
}
