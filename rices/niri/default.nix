{ lib, ... }:
{
  imports = [
    ./alacritty.nix
    ./kitty.nix
    ./wezterm.nix
    ./niri.nix
    ./flights.nix
    ./swayidle.nix
    ./noctalia.nix
    ./noctalia-widgets.nix
    ./wallpaper
    ./stylix.nix
    ./qt.nix
  ];

  # The niri rice as a single enable-options Home-Manager module. Importing this
  # directory only *declares* the rice; `rices.niri.enable = true` (set per-host,
  # e.g. homes/tempest/default.nix) activates it — every submodule's config is
  # gated on it. This deliberately deviates from the repo's "explicit imports,
  # no options layer" convention; see docs/adr/0004-niri-rice-as-enable-module.md.
  #
  # Machine policy lives OUTSIDE the rice: e.g. the monitor layout (kanshi) lives
  # in homes/tempest/monitors.nix. (The bar's old storage/backup-health readout —
  # and the rices.niri.backupWidget options that fed it — were dropped in the
  # Noctalia v5 migration; v5's custom_button can't poll a script. See
  # rices/niri/noctalia-widgets.nix and ADR 0003.) See "machine policy" in
  # CONTEXT.md.
  options.rices.niri = {
    enable = lib.mkEnableOption "the niri desktop rice";
  };
}
