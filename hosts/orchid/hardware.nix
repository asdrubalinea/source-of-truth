{
  lib,
  config,
  pkgs,
  ...
}: let
  # 7800X3D per-core Curve Optimizer counts, cores 0-7; see curve-optimizer below.
  co = [(-25) (-25) (-25) (-20) (-25) (-15) (-25) (-25)];
in {
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {
    # Ryzen 7 7800X3D (Zen 4). Microcode comes from nixpkgs' redistributable
    # firmware here — no ucodenix, unlike tempest, whose Framework board ships
    # firmware that never gets AMD's updates.
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # SMU mailbox driver (/sys/kernel/ryzen_smu_drv), which curve-optimizer
    # below uses to set Curve Optimizer from Linux instead of the BIOS. Needs kernel.dev, which the
    # CachyOS cache doesn't carry, so enabling it builds the kernel once locally.
    cpu.amd.ryzen-smu.enable = true;

    # enableAllFirmware (rather than just redistributable) so a wifi/ethernet
    # card added to this box later works on first boot — there is no NIC in it
    # today beyond whatever the board provides.
    enableAllFirmware = true;
    enableRedistributableFirmware = true;

    logitech.wireless.enable = true;

    # DDC/CI for the ember rice's brightness keys and Noctalia's ddcutil
    # backend — a desktop's panels are all external, so there is no backlight
    # for brightnessctl. Loads i2c-dev and grants the `i2c` group access.
    i2c.enable = true;

    # Raphael's small RDNA2 iGPU and the RX 9070 XT (Gigabyte, Navi 48) are
    # both driven by amdgpu; graphics userspace and LACT live in the shared
    # modules/hardware/gpu-amd.nix module imported by orchid.
  };

  # 9070 XT tune, applied by lactd at boot. Setting this makes
  # /etc/lact/config.yaml a read-only store link, so the GUI can't change it —
  # retune here. Measured 2026-10-01 with 10 min of vkmark effect2d (headless
  # sway) per step at 297 W: -175 mV passes, -200 mV hangs the gfx ring and
  # forces a mode1 reset in under 5 min. vkmark is not proof, though: at -150
  # real games hung the gfx ring twice in one evening (2026-10-04, a java/GL
  # and a vkd3d title, each recovered only by mode1 reset), so -100 it is.
  # Against stock (330 W, 0 mV) at -150: -33 W, junction 100 -> 94 C, +4.9% FPS.
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
      voltage_offset = -100;
    };
    current_profile = null;
    auto_switch_profiles = false;
  };

  # Curve Optimizer, applied at boot (the SMU forgets it on every reset; the
  # BIOS stays at stock, so a bad value can't stop the machine booting). Uses
  # ZenStates-Core's Zen 4 commands: MP1 0x35 SetDldoPsmMargin, RSMU 0xD5 to
  # read back. Measured 2026-10-01 with mprime SSE huge FFTs on one core at a
  # time, 5 min per core per step: core 5 hard-resets at -35, core 3 logs
  # corrected decode MCEs at -40, core 0 fails mprime's rounding check at -45,
  # and the box reset with cores 1 and 2 at -45; 4/6/7 passed -40 and weren't
  # pushed. "Last pass + 5" (-35 x6, -30, -25) then passed a full load pass
  # but reset the box after a minute at idle — load tests miss idle/transition
  # instability — so each core sits 10+ below its worst result instead.
  # Single-core clocks plateau by -25 (~5010 vs ~5025 MHz at -35; stock
  # ~4860), so the extra margin costs almost nothing.
  # To retune: edit `co` above and apply; the unit re-runs when it changes.
  systemd.services.curve-optimizer = lib.mkIf config.hardware.cpu.amd.ryzen-smu.enable {
    description = "Per-core Curve Optimizer for the 7800X3D";
    after = ["systemd-modules-load.service"];
    wantedBy = ["multi-user.target"];
    unitConfig.ConditionPathExists = "/sys/kernel/ryzen_smu_drv/codename";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writers.writePython3 "curve-optimizer" {} ''
        import struct
        import sys

        D = "/sys/kernel/ryzen_smu_drv/"
        CO = [${lib.concatMapStringsSep ", " toString co}]


        def cmd(box, op, arg):
            with open(D + "smu_args", "wb") as f:
                f.write(struct.pack("<6I", arg, 0, 0, 0, 0, 0))
            with open(D + box, "wb") as f:
                f.write(struct.pack("<I", op))
            with open(D + box, "rb") as f:
                st = struct.unpack("<I", f.read(4))[0]
            if st != 1:
                sys.exit(f"{box} {op:#x}: SMU status {st:#x}")
            with open(D + "smu_args", "rb") as f:
                return struct.unpack("<6i", f.read(24))[0]


        with open(D + "codename") as f:
            if int(f.read()) != 20:
                sys.exit("not Raphael: these command IDs would be wrong")
        for core, margin in enumerate(CO):
            if not -50 <= margin <= 0:
                sys.exit(f"core {core}: refusing margin {margin}")
            cmd("mp1_smu_cmd", 0x35, (core << 20) | (margin & 0xFFFF))
        got = [cmd("rsmu_cmd", 0xD5, core << 20) for core in range(len(CO))]
        print("curve optimizer:", got)
        if got != CO:
            sys.exit(f"read back {got}, wanted {CO}")
      '';
    };
  };
  # Whether S3 keeps the margins is untested; re-applying is harmless.
  powerManagement.resumeCommands = lib.mkIf config.hardware.cpu.amd.ryzen-smu.enable ''
    ${config.systemd.package}/bin/systemctl restart curve-optimizer.service
  '';
}
