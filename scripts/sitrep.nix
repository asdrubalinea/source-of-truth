# Home-manager side of sitrep. The derivation lives in packages/sitrep.nix so
# hosts without a home config can install it system-wide.
{pkgs, ...}: {
  home.packages = [(pkgs.callPackage ../packages/sitrep.nix {})];
}
