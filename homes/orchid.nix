{
  pkgs,
  inputs,
  ...
}: let
  arc-size = (
    pkgs.writeShellScriptBin "arc-size" ''
      cat /proc/spl/kstat/zfs/arcstats | grep '^size ' | awk '{ print $3 }' | awk '{ print $1 / (1024 * 1024 * 1024) " GiB" }'
    ''
  );

  nix-size = (
    pkgs.writeShellScriptBin "nix-size" ''
      zfs list -o name,used -t filesystem,volume -Hp | awk -v dataset='rpool/nix' '$1 == dataset { printf "%.0f GiB", $2/1024/1024/1024 }'
    ''
  );
in {
  imports = [
    # No WM for now, so no ../rices/estradiol (hyprland/waybar/stylix/kitty…)
    # and no hyprland HM module. Both come back together.
    ../desktop/helix.nix

    # Applying and cleaning is `nh` (enabled in hosts/orchid/default.nix):
    # `nh os switch`, `nh home switch -b backup`, `nh clean all`.
    ../scripts/port-forward.nix
    # Needs rpool/vms first; see disks/orchid.nix.
    ../scripts/ocelot.nix

    ../misc/fish.nix
    ../desktop/tmux.nix
    ../desktop/zellij.nix

    ../desktop/home-packages.nix
    ../desktop/opencode.nix
    ../desktop/ssh.nix
    ../desktop/starship.nix
    ../desktop/yt-dlp.nix
    # ../desktop/hn-tui.nix reads config.lib.stylix.colors to theme itself, and
    # stylix is not wired in without a rice — it comes back with the WM.
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home = {
    username = "irene";
    homeDirectory = "/home/irene";
    stateVersion = "23.05";
  };

  home.sessionVariables = {
    EDITOR = "${pkgs.helix}/bin/hx";

    # distrobox probes podman, then docker, and both are enabled on this host
    # (system/virtualization.nix), so leave nothing to the probe: a broken
    # podman then says so instead of quietly using the rootful daemon.
    DBX_CONTAINER_MANAGER = "podman";
  };

  programs.emacs = {
    enable = false;
    package = pkgs.emacs-pgtk;
  };

  programs.git = {
    enable = true;
    signing.format = null;
    settings.user = {
      name = "Irene";
      email = "git@irene.foo";
    };
  };

  home.packages = [
    arc-size
    nix-size
  ];

  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };

  # Dropped with the desktop: ../desktop/warp.nix (GUI terminal, and a long
  # from-source Rust build), programs.vscode's FHS wrapper, and
  # services.gnome-keyring — there is no graphical session to unlock it.
}
