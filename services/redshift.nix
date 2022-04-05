{ config, pkgs, ... }:

{
  # Milan
  location = {
    provider = "manual";
    latitude = 45.46;
    longitude = 9.19;
  };

  services.redshift = { enable = true; };
}
