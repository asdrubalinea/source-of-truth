{pkgs, ...}: {
  # Native gaming on the 9070 XT: Steam + Proton on Mesa RADV. The graphics
  # stack itself (hardware.graphics + enable32Bit, vulkan-tools) comes from
  # ../../../modules/hardware/gpu-amd.nix — RADV is Mesa's default AMD Vulkan
  # driver, so there is nothing to select. The win11 VM (./gaming-vm.nix) is
  # the other way to play; with passthrough on it borrows the same card, so
  # the two never overlap.
  #
  # Per-game launch options (Steam -> Properties -> General):
  #   mangohud gamemoderun %command%

  programs = {
    # System-level rather than home-manager: the module also turns on 32-bit
    # graphics (hardware.graphics.enable32Bit) and the controller udev rules.
    steam = {
      enable = true;
      # GE-Proton beside Valve's builds; pick it per game under Compatibility.
      extraCompatPackages = [pkgs.proton-ge-bin];

      # A "Steam (gamescope)" entry in tuigreet's session list (session.nix
      # reads sessionData.desktops): Big Picture on gamescope straight on DRM,
      # no niri underneath. This is the HDR route — niri has no colour
      # management (ADR 0009), so gamescope nested inside it cannot put an HDR
      # signal on the panel. HDR also has to be switched on once in Big
      # Picture -> Settings -> Display. VRR stays off as on the desktop:
      # QD-OLED + VRR flickers.
      #
      # The session file pins steam-gamescope by store path and tuigreet reads
      # the session list it was started with, so an edit to `args` only
      # reaches the greeter after greetd restarts (a reboot), not on switch.
      gamescopeSession = {
        enable = true;
        args = [
          "-W 3840"
          "-H 2160"
          "-r 165"
          "--hdr-enabled"
          # The OLED's connector on the 9070 XT. Unlike kanshi, gamescope
          # matches by connector, not EDID — with the portable BOE on HDMI-A-1
          # also lit it otherwise picks that one. Moving the OLED's cable to
          # another port means updating this.
          "--prefer-output DP-2"
        ];
      };

      # remotePlay.openFirewall = true;
      # dedicatedServer.openFirewall = true;
      # localNetworkGameTransfers.openFirewall = true;
    };

    # Nested gamescope under niri, for per-game upscaling or a frame cap.
    gamescope = {
      enable = true;
      # The Vulkan WSI layer gamescope needs for HDR and its own swapchain.
      enableWsi = true;
      # Left off: the cap_sys_nice wrapper fails inside Steam's bwrap sandbox.
      capSysNice = false;
    };

    # `gamemoderun`: performance governor and renice while a game runs. The
    # polkit rule that lets it switch governor without a prompt keys on the
    # `gamemode` group (users/irene.nix).
    gamemode.enable = true;
  };

  environment.systemPackages = with pkgs; [
    mangohud
    # Proton outside Steam: `GAMEID=0 WINEPREFIX=~/Games/prefixes/<game> umu-run game.exe`.
    umu-launcher
  ];

  # umu-run's default Proton: the same GE-Proton Steam gets, from the store,
  # instead of umu downloading its own copy (PROTONPATH=GE-Proton) into ~/.local.
  environment.sessionVariables.PROTONPATH = "${pkgs.proton-ge-bin.steamcompattool}";
}
