{
  lib,
  pkgs,
  config,
  ...
}:
# mitos (the helix fork, `ms`; package in ./cli-packages.nix) reads helix's
# theme format unchanged, so it gets the same `nano` theme — the one value from
# ./helix-theme.nix, not a copy, so the two editors can't drift apart. Gated
# like that file: the theme only exists where stylix supplies a palette.
let
  toml = pkgs.formats.toml {};
in
  lib.mkIf (config.programs.helix.themes ? nano) {
    xdg.configFile = {
      "mitos/themes/nano.toml".source = toml.generate "mitos-theme-nano" config.programs.helix.themes.nano;
      "mitos/config.toml".source = toml.generate "mitos-config" {theme = "nano";};
    };
  }
