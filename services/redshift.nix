{ config, pkgs, ... }:

{
  # Las Palmas de Gran Canaria
  location = {
    provider = "manual";
    latitude = 28.1235;
    longitude = -15.4363;
  };

  services.redshift = { enable = true; };
}
