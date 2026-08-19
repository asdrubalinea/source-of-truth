{inputs, ...}:
# The mango compositor layer of the ember rice. mango is a dwl descendant
# (wlroots + scenefx) with a PaperWM-style `scroller` layout, which is what makes
# it a plausible stand-in for niri; the rest of the desktop above it is unchanged.
# Gated on `rices.ember.mango.enable`.
#
# The Home-Manager module comes from mango's own flake, not nixpkgs: nixpkgs ships
# only a 2-option NixOS module (`programs.mango.{enable,package}`) and no HM module
# at all, so without the flake the config file would have to be hand-written as a
# dotfile. The flake's module takes a structured attrset, renders config.conf, and
# — the reason it is worth an input — runs `mango -c <file> -p` at BUILD time, so a
# key renamed upstream fails the rebuild instead of dropping you at a broken
# session. See docs/adr/0012-one-rice-two-compositors.md.
#
# `./system.nix` is the NixOS half and is imported by the host, not from here.
{
  imports = [
    inputs.mangowm.hmModules.mango
    ./mango.nix
  ];
}
