{ config, pkgs, ... }:

{

  boot = {
    extraModprobeConfig = "options nvidia-drm modeset=1";
    initrd.kernelModules =
      [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.beta;
      powerManagement.enable = true;

      modesetting.enable = true;
    };
  };
}
