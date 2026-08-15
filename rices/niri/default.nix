{ lib, ... }:
{
  imports = [
    ./alacritty.nix
    ./kitty.nix
    ./wezterm.nix
    ./niri.nix
    ./tofi.nix
    ./flights.nix
    ./swayidle.nix
    ./pip-follow.nix
    ./marquee.nix
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
  # Machine policy lives OUTSIDE the rice — a rice describes what the desktop IS,
  # independent of the machine under it. Four things currently cross that seam,
  # and they cross in two different directions:
  #
  #   - the monitor layout (kanshi) is entirely outside, in
  #     homes/tempest/monitors.nix — the rice never sees it;
  #   - `rices.niri.marquee` is set from there too, because which panel carries a
  #     band is a fact about the panel's mount (the option is declared next to its
  #     use, in ./marquee.nix, since it gates that whole file);
  #   - `stylix.fonts.sizes.terminal` and Noctalia's `location.address` are
  #     *defined* by the home config (homes/tempest/default.nix) into modules the
  #     rice also configures — no rice option needed, because the rice reads
  #     neither value;
  #   - `internalOutput` (below) goes the other way: the rice DOES read it, so it
  #     is an option here with a convention default a host can override.
  #
  # The rice knows no hostnames. If you find yourself writing `hostname == "…"`
  # inside rices/niri, the fact belongs in homes/<host>/ instead.
  # (The bar's old storage/backup-health readout —
  # and the rices.niri.backupWidget options that fed it — were dropped in the
  # Noctalia v5 migration; v5's custom_button can't poll a script. See
  # rices/niri/noctalia-widgets.nix and ADR 0003.) See "machine policy" in
  # CONTEXT.md.
  options.rices.niri = {
    enable = lib.mkEnableOption "the niri desktop rice";

    internalOutput = lib.mkOption {
      type = lib.types.str;
      default = "eDP-1";
      description = ''
        The laptop's built-in panel, by DRM connector name. The rice needs it to
        tell "adjust the backlight" from "adjust an external over DDC/CI" (see
        `brightnessAdjust` in ./niri.nix) — that is the one place the rice cares
        which output is internal.

        The default is the DRM convention, not a fact about any particular
        machine; a host whose panel enumerates differently overrides it from
        homes/<host>/. Was hard-coded inside the brightness script until it was
        lifted here.
      '';
    };
  };
}
