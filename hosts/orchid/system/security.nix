{ ... }:
{
  security.sudo.enable = true;
  security.doas.enable = true;

  security.pam.services.sddm.enableKwallet = true;

  security.doas.extraRules = [
    {
      users = [ "irene" ];
      keepEnv = true;
      noPass = true;
    }
  ];

  # security.polkit.enable = true;
}
