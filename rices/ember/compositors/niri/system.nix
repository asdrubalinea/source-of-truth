{
  lib,
  pkgs,
  ...
}:
# NixOS half of the niri compositor layer: the compositor package itself and the
# `niri-session` wayland-session entry the greeter lists. Furniture that both
# layers share (fonts, upower, PAM services) lives in ../../system.nix.
{
  programs.niri = {
    enable = true;
    # Must be set explicitly. niri-flake's module default is
    # `(make-package-set pkgs).niri-stable`, a second, different niri build.
    # pkgs.niri-unstable is the one the rest of the layer uses — a local build
    # against our nixpkgs, not niri-flake's prebuilt output, because only that
    # can load our mesa (see niriPrebuiltOverlay in flake.nix).
    #
    # This is the compositor greetd launches (`niri-session` ships inside this
    # package), so every `niri msg` in the layer must come from the same
    # derivation — a version mismatch prints a banner instead of JSON and
    # silently breaks the `--json` consumers. See ./niri.nix.
    package = pkgs.niri-unstable;
  };

  # niri-flake's module ships the session's polkit agent (polkit-kde) but hangs
  # it off `niri.service`, so under mango nothing answered polkit and every
  # prompt failed outright (Signal: "An error occurred while requesting system
  # authentication"). graphical-session.target is reached by both layers.
  systemd.user.services.niri-flake-polkit.wantedBy = lib.mkForce ["graphical-session.target"];
}
