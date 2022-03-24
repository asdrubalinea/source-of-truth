{ config, pkgs, ... }:

let
  # Execute app with prime offloading
  nvidiaPrime = pkgs.writeScriptBin "prime-run" ''
    #!${pkgs.stdenv.shell}
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    exec -a "$0" "$@"
  '';
in
{
  nixpkgs.config.allowUnfree = true;

  boot = {
    extraModprobeConfig = "options nvidia-drm modeset=1";
    initrd.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];

  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware = {
    opengl = {
      driSupport = true;
      driSupport32Bit = true;
    };

    nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.beta;
      powerManagement.enable = true;

      prime = {
        offload.enable = true;
        amdgpuBusId = "PCI:05:0:0";
        nvidiaBusId = "PCI:01:0:0";
      };

      modesetting.enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    nvidiaPrime
  ];
}
