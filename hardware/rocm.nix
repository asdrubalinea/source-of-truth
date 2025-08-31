{ pkgs, ... }: {
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      
      # Enhanced graphics packages for gaming
      extraPackages = with pkgs; [
        # AMD Vulkan drivers
        amdvlk
        vulkan-loader
        vulkan-validation-layers
        vulkan-extension-layer
        
        # Mesa drivers and extensions
        mesa
        
        # ROCm OpenCL support for compute workloads
        rocmPackages.clr.icd
        rocmPackages.rocm-runtime
        
        # Additional video acceleration
        libva
        libvdpau-va-gl
        vaapiVdpau
      ];
      
      # 32-bit graphics packages for Wine compatibility
      extraPackages32 = with pkgs.pkgsi686Linux; [
        amdvlk
        vulkan-loader
        mesa
        libva
        libvdpau-va-gl
        vaapiVdpau
      ];
    };
  };

  # ROCm environment setup for compute applications
  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
    "L+    /opt/rocm      -    -    -     -    ${pkgs.rocmPackages.rocm-runtime}"
  ];

  # ROCm and monitoring packages
  environment.systemPackages = with pkgs; [
    # ROCm packages
    rocmPackages.rocminfo
    rocmPackages.clr.icd
    rocmPackages.rocm-smi
    rocmPackages.rocm-runtime
    rocmPackages.hip-common
    
    # GPU monitoring and management
    radeontop          # AMD GPU usage monitor
    nvtopPackages.amd  # htop-like GPU monitor
    clinfo             # OpenCL information
    
    # Vulkan utilities
    vulkan-tools       # vulkaninfo, vkcube
    vulkan-loader
    vulkan-validation-layers
    
    # Graphics debugging and profiling
    renderdoc          # Graphics debugger
    mesa-demos         # glxgears, etc.
  ];

  # ROCm environment variables for RX 6700 XT optimal gaming performance
  environment.variables = {
    ROC_ENABLE_PRE_VEGA = "1";
    HSA_OVERRIDE_GFX_VERSION = "10.3.1";  # RX 6700 XT specific
    AMD_VULKAN_ICD = "RADV";              # Use RADV for gaming
    RADV_PERFTEST = "gpl,nggc,sam";       # Enable performance features
    
    # Mesa optimizations
    MESA_LOADER_DRIVER_OVERRIDE = "radeonsi";
    mesa_glthread = "true";
    
    # AMDGPU performance for RX 6700 XT
    AMDGPU_TARGETS = "gfx1031";          # RX 6700 XT architecture
  };

  # Kernel modules for AMD GPU
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "amdgpu" ];
  
  # AMD GPU specific kernel parameters
  boot.kernelParams = [
    "amdgpu.dc=1"          # Enable Display Core
    "amdgpu.dpm=1"         # Enable Dynamic Power Management
    "amdgpu.gpu_recovery=1" # Enable GPU recovery
    "amdgpu.ppfeaturemask=0xffffffff" # Enable all power play features
  ];

  # Udev rules for AMD GPU access
  services.udev.extraRules = ''
    # AMD GPU access for users
    SUBSYSTEM=="drm", KERNEL=="renderD*", GROUP="render", MODE="0664"
    SUBSYSTEM=="drm", KERNEL=="card*", GROUP="video", MODE="0664"
    
    # ROCm device access
    SUBSYSTEM=="kfd", KERNEL=="kfd", GROUP="render", MODE="0666"
  '';
}
