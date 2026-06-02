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
      # Bound how many signed UKIs accumulate on the ESP (2G on tempest).
      configurationLimit = 10;
    };

    bootspec.enable = true;
  };
}
