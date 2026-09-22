{pkgs, ...}: {
  # AMDGPU
  #
  # Expose the Overdrive controls used by LACT. This enables the driver
  # interface; it does not apply an undervolt, power limit, fan curve, or
  # overclock by itself.
  hardware.amdgpu.overdrive.enable = true;

  # LACT daemon + GUI for GPU monitoring and configuration.
  services.lact.enable = true;

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
