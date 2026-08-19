{
  inputs,
  pkgs,
  ...
}:
# NixOS half of the mango compositor layer: the compositor package, its portals,
# and the wayland-session entry the greeter lists (mango's derivation carries
# `providedSessions = [ "mango" ]`, which the module turns into a
# `services.displayManager.sessionPackages` entry — the same mechanism
# `programs.niri` uses). Furniture shared by both layers is in ../../system.nix.
#
# The module comes from mango's flake, not nixpkgs. It carries
# `disabledModules = [ "programs/wayland/mango.nix" ]`, so importing it REPLACES
# nixpkgs' own two-option module rather than fighting it — do not import both.
{
  imports = [inputs.mangowm.nixosModules.mango];

  programs.mango = {
    enable = true;
    # Pinned explicitly so the compositor greetd launches, the HM module's
    # config-validation binary, and the `mmsg` that ../../swayidle.nix calls at
    # idle are all one derivation.
    package = pkgs.mango;
  };

  # NOTE: this module also sets `xdg.portal.wlr.enable = mkDefault true` and adds
  # xdg-desktop-portal-wlr system-wide, which is present in the niri session too.
  # Portal backends are selected per `XDG_CURRENT_DESKTOP`, and niri keeps its own
  # `xdg.portal.config.niri`, so the two should not interfere — but screencast
  # under niri is the thing to re-check first if it starts behaving oddly after
  # this lands. See "Known risks" in docs/adr/0012.
}
