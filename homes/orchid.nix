{
  pkgs,
  lib,
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
    # Desktop environment and theming — the ember rice, as on tempest
    # (declares rices.ember.*; enabled below).
    inputs.stylix.homeModules.stylix
    ../rices/ember
    ./orchid/monitors.nix # machine policy: monitor identity + mode (kanshi)

    ../desktop/helix.nix

    # Applying and cleaning is `nh` (enabled in hosts/orchid/default.nix):
    # `nh os switch`, `nh home switch -b backup`, `nh clean all`.
    ../scripts/port-forward.nix
    ../scripts/claude-sandboxed.nix
    ../scripts/cage.nix
    # Needs rpool/vms first; see disks/orchid.nix.
    ../scripts/ocelot.nix
    ../scripts/sitrep.nix

    ../misc/fish.nix
    ../desktop/tmux.nix
    ../desktop/zellij.nix

    ../desktop/home-packages.nix
    ../desktop/opencode.nix
    ../desktop/ssh.nix
    ../desktop/starship.nix
    ../desktop/yt-dlp.nix
    ../desktop/hn-tui.nix
  ];

  # Both compositor layers, picked per login at the greeter — same as tempest
  # (ADR 0012). The monitor layout is kanshi, in ./orchid/monitors.nix.
  rices.ember = {
    enable = true;
    niri.enable = true;
    mango.enable = true;
  };

  # Machine policy: where this machine is (rices/ember/noctalia.nix keeps
  # Noctalia from geolocating by IP, so it needs a place name).
  programs.noctalia.settings.location.address = "Las Palmas, Spain";

  # Keep the Wayland client services alive across a compositor restart: retry
  # forever, slowly, instead of burning systemd's 5 tries in half a second and
  # sitting dead. Same block as homes/tempest/default.nix, which has the full
  # story; wlsunset is tempest-only, so it is not listed here.
  systemd.user.services = lib.genAttrs ["swayidle" "noctalia" "wayland-pipewire-idle-inhibit"] (_: {
    Unit.StartLimitIntervalSec = 0;
    Service.RestartSec = 2;
  });

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

  # Not brought back with the desktop: ../desktop/warp.nix (GUI terminal, and a
  # long from-source Rust build) and programs.vscode's FHS wrapper.
}
