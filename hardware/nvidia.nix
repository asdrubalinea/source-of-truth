{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  boot = {
    extraModprobeConfig = "options nvidia-drm modeset=1";
    initrd.kernelModules =
      [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware = {
    opengl = {
      driSupport = true;
      driSupport32Bit = true;
    };

    nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.beta;
      modesetting.enable = false;
    };
  };
}
