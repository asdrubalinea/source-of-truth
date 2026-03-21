{ ... }:
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
  };
}
