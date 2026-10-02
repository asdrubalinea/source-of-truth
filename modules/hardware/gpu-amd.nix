{pkgs, ...}: {
  # AMDGPU
  #
  # Expose the Overdrive controls used by LACT. This enables the driver
  # interface; it does not apply an undervolt, power limit, fan curve, or
  # overclock by itself.
  hardware.amdgpu.overdrive.enable = true;

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
