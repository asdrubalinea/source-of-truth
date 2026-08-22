{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    curl
    git
    helix
    neovim
    git-crypt
    ntfs3g
    # TPM2 tooling: needed to enrol the LUKS volume for auto-unlock
    # (systemd-cryptenroll --tpm2-device=auto) — see docs/orchid-install.md.
    tpm2-tools
    swtpm # software TPM for libvirtd guests
    # Terminfo only (no wezterm build) so ssh from tempest, which runs
    # TERM=wezterm, gets a known terminal here.
    wezterm.terminfo
  ];

  environment.variables = {
    EDITOR = "${pkgs.helix}/bin/hx";
  };

  programs = {
    fish.enable = true;
    mosh.enable = true;

    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    # For VSCode remote / prebuilt language servers.
    nix-ld.enable = true;
  };

  # Dropped with the desktop: programs.hyprland, programs.steam and the
  # vulkan-tools/loader/validation-layers packages. Nothing here runs a display
  # server for now — put them back alongside the rice when a WM returns.
}
