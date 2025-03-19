{ ... }: {
  services.glance = {
    enable = true;
    settings = ./glance.yml;
  };
}
