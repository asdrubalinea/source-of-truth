{lib, ...}: {
  imports = [
    ./alacritty.nix
    ./kitty.nix
    ./wezterm.nix
    ./tofi.nix
    ./flights.nix
    ./swayidle.nix
    ./noctalia.nix
    ./noctalia-widgets.nix
    ./wallpaper
    ./stylix.nix
    ./qt.nix
    ./compositors/niri
    ./compositors/mango
  ];

  # The ember rice as a single enable-options Home-Manager module. Importing this
  # directory only *declares* the rice; `rices.ember.enable = true` (set per-host,
  # e.g. homes/tempest/default.nix) activates it — every submodule's config is
  # gated on it. This deliberately deviates from the repo's "explicit imports,
  # no options layer" convention; see docs/adr/0004-niri-rice-as-enable-module.md
  # and its amendment, docs/adr/0012-one-rice-two-compositors.md.
  #
  # ONE RICE, TWO COMPOSITORS. Everything in this directory is the rice: the bar,
  # launcher, notifications, lockscreen, terminals, theming, idle handling and
  # wallpaper. `./compositors/<name>` holds one *compositor layer* — the window
  # manager itself plus the bindings, layout and window rules that only its
  # config language can express. Both layers can be enabled at once (they are, on
  # tempest); which one actually runs is chosen at the greeter, per login. The
  # rule that falls out of that: no option may be *defined* by two layers, since
  # both are evaluated in the same generation and would collide. Anything both
  # need belongs up here; anything only one needs may be declared inside it (the
  # marquee is), as long as the other never touches it. In the other direction,
  # the furniture must never name a compositor — where it genuinely needs one, it
  # branches at runtime on the live session, as ../swayidle.nix does.
  #
  # Machine policy lives OUTSIDE the rice — a rice describes what the desktop IS,
  # independent of the machine under it. Four things currently cross that seam,
  # and they cross in two different directions:
  #
  #   - the monitor layout (kanshi) is entirely outside, in
  #     homes/tempest/monitors.nix — the rice never sees it. It needs no porting
  #     between compositors: both niri and mango implement
  #     wlr-output-management, which is the protocol kanshi drives;
  #   - `rices.ember.marquee` is set from there too, because which panel carries a
  #     band is a fact about the panel's mount (the option is declared next to its
  #     use, in ./compositors/niri/marquee.nix, since it gates that whole file);
  #   - `stylix.fonts.sizes.terminal` and Noctalia's `location.address` are
  #     *defined* by the home config (homes/tempest/default.nix) into modules the
  #     rice also configures — no rice option needed, because the rice reads
  #     neither value;
  #   - `internalOutput` (below) goes the other way: the rice DOES read it, so it
  #     is an option here with a convention default a host can override.
  #
  # The rice knows no hostnames. If you find yourself writing `hostname == "…"`
  # inside rices/ember, the fact belongs in homes/<host>/ instead.
  # (The bar's old storage/backup-health readout — and the backupWidget options
  # that fed it — were dropped in the Noctalia v5 migration; v5's custom_button
  # can't poll a script. See ./noctalia-widgets.nix and ADR 0003.) See "machine
  # policy" in CONTEXT.md.
  options.rices.ember = {
    enable = lib.mkEnableOption "the ember desktop rice";

    # One flag per compositor layer, both gated on the rice being enabled at all.
    # These are not mutually exclusive and are not a "pick one" — both are true on
    # tempest, because both sessions are installed and the choice is made at the
    # greeter (hosts/tempest/system/session.nix). Turning one off removes its
    # session entry and its config; it does not change the other.
    niri.enable = lib.mkEnableOption "the niri compositor layer";
    mango.enable = lib.mkEnableOption "the mango compositor layer";

    internalOutput = lib.mkOption {
      type = lib.types.str;
      default = "eDP-1";
      description = ''
        The laptop's built-in panel, by DRM connector name. The niri layer needs
        it to tell "adjust the backlight" from "adjust an external over DDC/CI"
        (see `brightnessAdjust` in ./compositors/niri/niri.nix) — that is the one
        place the rice cares which output is internal.

        The default is the DRM convention, not a fact about any particular
        machine; a host whose panel enumerates differently overrides it from
        homes/<host>/. Was hard-coded inside the brightness script until it was
        lifted here.

        Read by the niri layer only: the mango layer has no brightness binding
        (ADR 0012), so nothing there consults this.
      '';
    };
  };
}
