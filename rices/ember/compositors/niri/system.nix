{ pkgs, ... }:
# NixOS half of the niri compositor layer: the compositor package itself and the
# `niri-session` wayland-session entry the greeter lists. Furniture that both
# layers share (fonts, upower, PAM services) lives in ../../system.nix.
{
  programs.niri = {
    enable = true;
    # Must be set explicitly. niri-flake's module default is
    # `(make-package-set pkgs).niri-stable`, which reaches past the
    # niriPrebuiltOverlay aliases in flake.nix and compiles niri against our
    # nixpkgs — a local Rust build that no cache can serve. pkgs.niri-unstable
    # is the alias to niri-flake's own prebuilt output.
    #
    # This is the compositor greetd launches (`niri-session` ships inside this
    # package), so every `niri msg` in the layer must come from the same
    # derivation — a version mismatch prints a banner instead of JSON and
    # silently breaks the `--json` consumers. See ./niri.nix.
    package = pkgs.niri-unstable;
  };
}
