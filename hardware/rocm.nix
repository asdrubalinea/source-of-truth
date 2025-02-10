{ config, lib, pkgs, ... }:

{
  # hardware = {
  #   graphics = {
  #     enable = true;
  #     enable32Bit = true;
  #   };
  # };

  # hardware.opengl.extraPackages = with pkgs; [
  #   # amdvlk
  #   # rocm-opencl-icd
  #   # rocm-opencl-runtime
  #   #
  #   #    rocm-opencl-icd
  #       rocm-runtime
  #       rocminfo
  #       rocm-smi
  #       rocm-device-libs
  # ];

  # systemd.tmpfiles.rules = [
  #   "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  #   "L+	   /opt/amdgpu	   -    -    -     -    ${pkgs.libdrm}"
  # ];

  environment.systemPackages = with pkgs.rocmPackages; [
    rocminfo
    clr.icd
    # rccl
    # rocm-smi
    # miopen-hip
    # hip-common
  ];
}
