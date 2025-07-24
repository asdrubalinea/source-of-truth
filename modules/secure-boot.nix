{ lib
, ...
}:

{
  # Boot Configuration
  boot = {
    initrd = {
      systemd.enable = true;
    };

    loader = {
      systemd-boot.enable = lib.mkForce false;
    };

    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    bootspec.enable = true;
  };
}
