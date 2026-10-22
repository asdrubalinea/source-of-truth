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
    # Signal's polkit actions only (org.signalapp.enable-backups & co.):
    # polkitd reads them from /run/current-system/sw/share/polkit-1, which a
    # home-manager install never reaches, so enabling backups fails with
    # "enable-backups action not registered". Just the policies, so there is
    # no second Signal binary or .desktop entry beside the HM one.
    (runCommand "signal-desktop-polkit" {} ''
      mkdir -p $out/share
      cp -r ${signal-desktop}/share/polkit-1 $out/share/
    '')
  ];

  security.polkit.enable = true;

  environment.variables = {
    EDITOR = "${pkgs.helix}/bin/hx";
  };

  programs = {
    fish.enable = true;
    mosh.enable = true;
    mtr.enable = true;

    # System-level so the module creates the `wireshark` group and setcap-wraps
    # dumpcap (irene is a member, users/irene.nix); a home-manager install would
    # be a GUI that sees no interface. See hosts/tempest/system/environment.nix.
    wireshark = {
      enable = true;
      package = pkgs.wireshark;
    };

    appimage = {
      enable = true;
      binfmt = true;
    };

    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    # For VSCode remote / prebuilt language servers.
    nix-ld.enable = true;

    # Steam lives in ./gaming.nix.
  };
}
