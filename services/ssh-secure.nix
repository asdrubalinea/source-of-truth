{ config, pkgs, ... }:

{
  services.openssh = {
    enable = true;
    passwordAuthentication = false;
    permitRootLogin = "prohibit-password";
    kbdInteractiveAuthentication = false;
  };

  services.fail2ban.enable = true;
}
