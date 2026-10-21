{pkgs, ...}: {
  # AMDGPU
  #
  # Expose the Overdrive controls used by LACT. This enables the driver
  # interface; it does not apply an undervolt, power limit, fan curve, or
  # overclock by itself.
  hardware.amdgpu.overdrive.enable = true;
  # nixpkgs' default mask for overdrive, 0xfffd7fff, also clears GFXOFF (bit
  # 15) and memory stutter mode (bit 17), the two features that let an idle
  # GPU power-gate its shader core and put VRAM in self-refresh between
  # scanouts. It does that to avoid flicker reported on some setups. This is
  # the kernel's own default (0xfff7bfff) plus only the overdrive bit (14). If
  # a panel flickers, go back to 0xfffd7fff.
  hardware.amdgpu.overdrive.ppfeaturemask = "0xfff7ffff";

  # LACT daemon + GUI for GPU monitoring and configuration.
  services.lact.enable = true;

  # The GUI writes its profiles to /etc/lact/config.yaml; both importers have a
  # tmpfs root, so without this every tune is gone at the next boot. (orchid
  # sets services.lact.settings instead, which makes the file a store link.)
  environment.persistence."/persist".directories = ["/etc/lact"];

  # Vulkan / OpenGL, including support for 32-bit applications.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # GPU diagnostics, monitoring, and benchmark tools.
  environment.systemPackages = with pkgs; [
    amdgpu_top
    vulkan-tools
    mesa-demos
    lm_sensors
    pciutils
    btop
    vkmark
  ];
}
