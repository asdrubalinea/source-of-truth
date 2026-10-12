{pkgs, ...}:
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
}
