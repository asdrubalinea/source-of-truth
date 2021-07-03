{ config, pkgs, ... }:

{
  services.xserver.config = ''
    Section "OutputClass"
        Identifier "AMDgpu"
        MatchDriver "amdgpu"
        Driver "amdgpu"
        Option "TearFree" "true"
    EndSection
  '';
}
