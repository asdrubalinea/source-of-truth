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
  # it lives with the host rather than in the ember rice (see CONTEXT.md).
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "radeonsi";
  };

  programs = {
    mtr.enable = true;

    # Wireshark has to be system-level: the module creates the `wireshark`
    # group and installs a setcap'd dumpcap wrapper, so members capture without
    # sudo (irene is in that group — see users/irene.nix). Installing the
    # package from home-manager instead would give a GUI that can't see any
    # interface. `package` defaults to wireshark-cli (tshark only), hence the
    # override for the Qt GUI. USB capture stays off: programs.wireshark.usbmon
    # would open every usbmon device to the group, which is broader than the
    # RTL-SDR/SDRplay work needs.
    wireshark = {
      enable = true;
      package = pkgs.wireshark;
    };

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
