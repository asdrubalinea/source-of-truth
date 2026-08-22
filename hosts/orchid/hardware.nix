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

    # No hardware.graphics: no discrete GPU and no display server on this host.
    # Raphael's small RDNA2 iGPU still drives the console via amdgpu
    # (system/boot.nix). Turn graphics on when a WM comes back, or if something
    # headless needs VA-API/OpenCL.
  };
}
