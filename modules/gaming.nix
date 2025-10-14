{ pkgs, lib, ... }:
{
  # Enable essential gaming hardware support
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Critical for Wine compatibility
  };

  # Gaming packages and launchers
  environment.systemPackages = with pkgs; [
    # Wine and compatibility layers
    wineWowPackages.stable # 32/64-bit Wine support
    wineWowPackages.staging # Staging Wine for latest compatibility
    winetricks # Essential Windows dependencies installer

    # Gaming launchers and tools
    (lutris.override {
      extraLibraries = pkgs: with pkgs; [
        # Essential libraries for Rockstar Launcher
        keyutils
        libkrb5
        libpng
        libpulseaudio
        libvorbis
        stdenv.cc.cc.lib
        xorg.libXcursor
        xorg.libXi
        xorg.libXinerama
        xorg.libXScrnSaver
        xorg.libXrandr
        xorg.libXxf86vm
        # Additional libraries for game compatibility
        openssl
        curl
        sqlite
        zlib
        freetype
        fontconfig
        glib
        gtk3
        cairo
        pango
        atk
        gdk-pixbuf
        # 32-bit versions
        pkgsi686Linux.openssl
        pkgsi686Linux.zlib
        pkgsi686Linux.freetype
        pkgsi686Linux.fontconfig
        pkgsi686Linux.glib
        pkgsi686Linux.gtk3
        pkgsi686Linux.cairo
        pkgsi686Linux.pango
        pkgsi686Linux.atk
        pkgsi686Linux.gdk-pixbuf
      ];
      extraPkgs = pkgs: with pkgs; [
        winetricks
        wineWowPackages.staging
        coreutils
        bash
        cabextract
        unzip
        wget
        curl
      ];
    })

    bottles # Alternative Wine manager
    mangohud # Performance overlay
    gamemode # Automatic performance optimization
    gamescope # SteamOS gaming compositor

    # Performance and monitoring tools
    vulkan-tools # Vulkan utilities (vulkaninfo)
    vulkan-loader # Vulkan loader
    vulkan-validation-layers # Vulkan debugging
    mesa # Mesa drivers

    # Additional gaming utilities
    protontricks # Winetricks for Proton
    heroic # Epic Games Store launcher
    legendary-gl # Epic Games Store CLI

    # Audio support
    pipewire # Modern audio system
    wireplumber # PipeWire session manager
    pulseaudio # PulseAudio compatibility
    alsa-lib # ALSA support

    # Input and peripheral support
    antimicrox # Gamepad to keyboard/mouse mapping
    evtest # Input device testing
  ];

  # Enhanced FHS compatibility for non-NixOS games
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      # Base system libraries
      stdenv.cc.cc
      zlib
      openssl
      curl
      fontconfig
      freetype
      glib
      gtk3
      cairo
      pango
      atk
      gdk-pixbuf
      dbus
      systemd
      # Graphics and Vulkan
      vulkan-loader
      mesa
      # Audio
      alsa-lib
      libpulseaudio
      pipewire
      # X11 and Wayland
      xorg.libX11
      xorg.libXcursor
      xorg.libXrandr
      xorg.libXi
      xorg.libXext
      xorg.libXfixes
      xorg.libXrender
      xorg.libXcomposite
      xorg.libXdamage
      wayland
      # Wine dependencies
      keyutils
      libkrb5
      libpng
      libvorbis
      libxml2
      libxslt
      # 32-bit libraries
      pkgsi686Linux.stdenv.cc.cc
      pkgsi686Linux.zlib
      pkgsi686Linux.openssl
      pkgsi686Linux.curl
      pkgsi686Linux.fontconfig
      pkgsi686Linux.freetype
      pkgsi686Linux.glib
      pkgsi686Linux.gtk3
      pkgsi686Linux.cairo
      pkgsi686Linux.pango
      pkgsi686Linux.atk
      pkgsi686Linux.gdk-pixbuf
      pkgsi686Linux.dbus
      pkgsi686Linux.vulkan-loader
      pkgsi686Linux.mesa
      pkgsi686Linux.alsa-lib
      pkgsi686Linux.libpulseaudio
      pkgsi686Linux.pipewire
      pkgsi686Linux.xorg.libX11
      pkgsi686Linux.xorg.libXcursor
      pkgsi686Linux.xorg.libXrandr
      pkgsi686Linux.xorg.libXi
      pkgsi686Linux.xorg.libXext
      pkgsi686Linux.xorg.libXfixes
      pkgsi686Linux.xorg.libXrender
      pkgsi686Linux.keyutils
      pkgsi686Linux.libkrb5
      pkgsi686Linux.libpng
      pkgsi686Linux.libvorbis
      pkgsi686Linux.libxml2
      pkgsi686Linux.libxslt
    ];
  };

  # GameMode configuration for automatic performance optimization
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        ioprio = 7;
        inhibit_screensaver = 1;
        softrealtime = "auto";
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        amd_performance_level = "high";
      };
      custom = {
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
        end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
      };
    };
  };

  # PipeWire low-latency audio configuration for gaming
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    # Low-latency audio configuration
    extraConfig.pipewire."92-low-latency" = {
      context.properties = {
        default.clock.rate = 48000;
        default.clock.quantum = 32;
        default.clock.min-quantum = 32;
        default.clock.max-quantum = 32;
      };
    };
  };

  # System-level gaming optimizations
  boot.kernel.sysctl = {
    # Increase file descriptor limits for games
    "fs.file-max" = 2097152;
    # Optimize network performance
    "net.core.rmem_default" = 262144;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_default" = 262144;
    "net.core.wmem_max" = 16777216;
    # Memory management for gaming
    "vm.max_map_count" = 2147483642;
    "vm.swappiness" = 1;
  };

  # DNS configuration for Rockstar Launcher connectivity
  networking.nameservers = [
    "1.1.1.1" # Cloudflare
    "8.8.8.8" # Google
  ];

  # Kernel parameters for gaming performance
  boot.kernelParams = [
    # Disable CPU mitigations for performance (security trade-off)
    # "mitigations=off"  # Uncomment for maximum performance

    # Memory and performance optimizations
    "transparent_hugepage=never"
    "processor.max_cstate=1"
    "intel_idle.max_cstate=0" # For Intel CPUs, harmless on AMD

    # GPU optimizations
    "amdgpu.dc=1"
    "amdgpu.dpm=1"
  ];

  # Enable Steam with additional compatibility
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;

    # Additional Steam packages
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  # Flatpak for additional game stores and launchers
  services.flatpak.enable = true;

  # XDG portals for proper desktop integration
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  # Font configuration for games requiring Windows fonts
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      corefonts
      vistafonts
      liberation_ttf
      dejavu_fonts
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
    ];

    fontconfig = {
      enable = true;
      antialias = true;
      hinting.enable = true;
      subpixel.rgba = "rgb";
      defaultFonts = {
        serif = [ "Liberation Serif" "DejaVu Serif" ];
        sansSerif = [ "Liberation Sans" "DejaVu Sans" ];
        monospace = [ "Liberation Mono" "DejaVu Sans Mono" ];
      };
    };
  };

  # Security considerations for gaming
  security.pam.loginLimits = [
    {
      domain = "@users";
      item = "rtprio";
      type = "-";
      value = "1";
    }
    {
      domain = "@users";
      item = "nice";
      type = "-";
      value = "-11";
    }
    {
      domain = "@users";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
  ];

  # Udev rules for gaming devices
  services.udev.extraRules = ''
    # Allow users to access gaming devices
    SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", MODE="0664", GROUP="users"
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="28de", MODE="0664", GROUP="users"
    
    # Generic HID devices for controllers
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0664", GROUP="users"
    
    # Enable realtime priority for audio group
    KERNEL=="rtc0", GROUP="audio"
  '';

  # Gaming-related environment variables
  environment.sessionVariables = {
    # DXVK optimizations
    DXVK_ASYNC = "1";
    DXVK_STATE_CACHE = "1";
    DXVK_STATE_CACHE_PATH = "$HOME/.cache/dxvk";

    # Wine optimizations
    WINEPREFIX = "$HOME/.wine";
    WINEDLLOVERRIDES = "winedbg.exe=d";

    # Performance optimizations
    __GL_SHADER_DISK_CACHE = "1";
    __GL_SHADER_DISK_CACHE_PATH = "$HOME/.cache/nvidia";

    # MangoHud configuration
    MANGOHUD = "1";
    MANGOHUD_CONFIGFILE = "$HOME/.config/MangoHud/MangoHud.conf";

    # VKD3D optimizations for DirectX 12
    VKD3D_CONFIG = "dxr";
  };
}
