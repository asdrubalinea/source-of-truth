{
  lib,
  config,
  ...
}: {
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {
    # Ryzen 7 7800X3D (Zen 4). Microcode comes from nixpkgs' redistributable
    # firmware here — no ucodenix, unlike tempest, whose Framework board ships
    # firmware that never gets AMD's updates.
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # enableAllFirmware (rather than just redistributable) so a wifi/ethernet
    # card added to this box later works on first boot — there is no NIC in it
    # today beyond whatever the board provides.
    enableAllFirmware = true;
    enableRedistributableFirmware = true;

    logitech.wireless.enable = true;

    # Raphael's small RDNA2 iGPU and the incoming discrete AMD GPU are both
    # driven by amdgpu; graphics userspace and LACT live in the shared
    # modules/hardware/gpu-amd.nix module imported by orchid.
  };
}
