{ config, lib, pkgs, ... }:

{
  hardware.opengl.extraPackages = with pkgs; [
    # amdvlk
    # rocm-opencl-icd
    # rocm-opencl-runtime
  ];
  hardware.opengl.driSupport = true;
  hardware.opengl.driSupport32Bit = true; # originally for Steam, could be removed from here

  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
    "L+	   /opt/amdgpu	   -    -    -     -    ${pkgs.libdrm}"
  ];

  environment.systemPackages = with pkgs.rocmPackages; [
    rocminfo
    clr.icd
    # rccl
    # rocm-smi
    # miopen-hip
    # hip-common
  ];
}
