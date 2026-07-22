{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    curl
    git
    helix
    neovim
    xwayland-satellite
    libva-utils # vainfo — verify VA-API hardware video decode
  ];

  environment.variables = {
    EDITOR = "${pkgs.helix}/bin/hx";
  };

  # Pin the VA-API driver to the native RDNA path. radeonsi is the correct
  # driver for this Strix Point iGPU's VCN video engine; pinning it stops libva
  # from mis-selecting the installed vdpau wrapper (libva-vdpau-driver), which
  # would route hardware video decode through a worse path. Harmless if decode
  # already works; verify with `vainfo`. This is AMD-specific machine policy, so
  # it lives with the host rather than in the niri rice (see CONTEXT.md).
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "radeonsi";
  };

  programs = {
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    dconf.enable = true;

    steam = {
      enable = true;
      # remotePlay.openFirewall = true;
      # dedicatedServer.openFirewall = true;
      # localNetworkGameTransfers.openFirewall = true;
    };

    appimage = {
      enable = true;
      binfmt = true;
    };
  };
}
