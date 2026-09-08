{lib, ...}: {
  imports = [
    ./alacritty.nix
    ./kitty.nix
    ./konsole.nix
    ./kde.nix
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

  # The ember rice as a single enable-options HM module. Importing this directory
  # only *declares* it; `rices.ember.enable = true` in the home config activates
  # it, and every submodule's config is gated on that. A deliberate deviation
  # from the repo's "explicit imports, no options layer" convention — see
  # ADR 0004 and its amendment ADR 0012.
  #
  # ONE RICE, TWO COMPOSITORS. Everything in this directory is the rice: bar,
  # launcher, notifications, lockscreen, terminals, theming, idle, wallpaper.
  # `./compositors/<name>` holds one compositor layer — the WM plus what only its
  # own config language can express. Both can be enabled at once (they are), and
  # which runs is chosen at the greeter per login. Two rules fall out of that:
  # no option may be DEFINED by two layers, since both evaluate in the same
  # generation and would collide (anything shared belongs up here); and the
  # furniture must never NAME a compositor — where it genuinely needs one it
  # branches at runtime on the live session, as ../swayidle.nix does.
  #
  # Machine policy lives OUTSIDE the rice, which describes what the desktop IS
  # independent of the machine under it. Four things cross that seam, in two
  # directions:
  #
  #   - the kanshi monitor layout is entirely outside, in
  #     homes/tempest/monitors.nix, and needs no porting between compositors
  #     since both implement wlr-output-management;
  #   - `rices.ember.marquee` is set from there too, because which panel carries
  #     a band is a fact about the panel's mount (declared next to its use in
  #     ./compositors/niri/marquee.nix, since it gates that whole file);
  #   - `stylix.fonts.sizes.terminal` and Noctalia's `location.address` are
  #     DEFINED by the home config into modules the rice also configures — no
  #     rice option needed, since the rice reads neither;
  #   - `internalOutput` goes the other way: the rice DOES read it, so it is an
  #     option here with a default a host can override.
  #
  # THE RICE KNOWS NO HOSTNAMES. If you find yourself writing `hostname == "…"`
  # in here, the fact belongs in homes/<host>/ instead. See "machine policy" in
  # CONTEXT.md.
  options.rices.ember = {
    enable = lib.mkEnableOption "the ember desktop rice";

    # One flag per compositor layer, both gated on the rice being enabled. NOT
    # mutually exclusive and not a "pick one" — both are true on tempest, since
    # both sessions are installed and the choice is made at the greeter. Turning
    # one off removes its session entry and config, and changes nothing else.
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

    ddcSleepMonitors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Panels whose panels-off power cycling must go through DDC/CI (VCP D6)
        instead of compositor DPMS, identified by the MFG:model:serial id that
        `ddcutil detect --brief` prints on its Monitor line (e.g.
        "BOE:Display:" — a trailing empty serial is part of the id).

        A bus-powered panel can't be DPMS-slept: cutting its DP signal
        power-cycles it off the bus and it reconnects a second later, lit — it
        never stays off, and the hotplug churn re-applies kanshi profiles
        mid-sleep. VCP D6 turns the panel dark while the DP link stays up: no
        hotplug, and the panel keeps answering DDC so the same channel wakes it.

        Machine policy — set from homes/<host>/monitors.nix, next to the kanshi
        profiles that know these panels' serials. Consumed by ./swayidle.nix's
        monitorPower dispatcher, mango branch only (niri's power-off-monitors is
        not routed through this list).
      '';
    };

    beforeSleepCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Commands to run on the way into suspend, after the lock surface is up and
        while swayidle still holds the logind sleep inhibitor — so they finish
        before the machine freezes. Keep them short and bounded: logind waits at
        most InhibitDelayMaxSec (5s) for the inhibitor to come back.

        Machine policy, set from homes/<host>/; the rice runs them without
        knowing what they are. This is an option rather than a second definition
        of `services.swayidle.events.before-sleep` because that option is a
        single string, claimed here by the locker — a machine with furniture to
        put away before the box freezes has nowhere else to hook. Consumed by
        ./swayidle.nix's lockBeforeSleep.
      '';
    };
  };
}
