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

    # Raphael's small RDNA2 iGPU and the RX 9070 XT (Gigabyte, Navi 48) are
    # both driven by amdgpu; graphics userspace and LACT live in the shared
    # modules/hardware/gpu-amd.nix module imported by orchid.
  };

  # 9070 XT tune, applied by lactd at boot. Setting this makes
  # /etc/lact/config.yaml a read-only store link, so the GUI can't change it —
  # retune here. Measured 2026-10-01 with 10 min of vkmark effect2d (headless
  # sway) per step at 297 W: -175 mV passes, -200 mV hangs the gfx ring and
  # forces a mode1 reset in under 5 min, so -150 keeps 25 mV of margin.
  # Against stock (330 W, 0 mV): -33 W, junction 100 -> 94 C, +4.9% FPS.
  # Junction runs ~31 C over edge either way — a mount/paste limit, not voltage.
  services.lact.settings = {
    version = 7;
    daemon = {
      log_level = "info";
      admin_group = "wheel";
      disable_clocks_cleanup = false;
    };
    apply_settings_timer = 5;
    gpus."1002:7550-1458:2424-0000:03:00.0" = {
      fan_control_enabled = false;
      power_cap = 297.0;
      voltage_offset = -150;
    };
    current_profile = null;
    auto_switch_profiles = false;
  };
}
