{ ... }:
# Machine policy for tempest: monitor identities and layout. These are per-host
# facts (specific BOE/Samsung/LG panel serials and their modes/positions), not
# part of the ember rice — a rice describes "what the desktop is", independent of
# the machine it runs on. Factored out of rices/ember so the rice stays portable.
# See the "machine policy" entry in CONTEXT.md and docs/adr/0004.
#
# NOTE on the portable BOE panel ("BOE Display Unknown"): its EDID preferred
# timing is 2560x1440@**60**, but the panel also does 100/120/144 at native res.
# So the `mode` pin is what carries the refresh rate — drop it and kanshi takes
# preferred and you get 60Hz at the right resolution, which reads as "correct but
# feels laggy". Pin the full `2560x1440@144.000`.
#
# Known cost of pinning: if the panel probes degraded (behind a hub, or on a DP
# link too starved for the pinned mode) the kernel prunes its mode list — in the
# worst case to a bare 640x480 — and kanshi logs
#   output '<head>' doesn't support mode '2560x1440@144.000000Hz'
# Because kanshi commits a profile atomically and does NOT fall through to the
# next matching profile, the ENTIRE profile then aborts: the OLED silently
# reverts to its 60Hz preferred mode and the lid panel wakes back up. That log
# line is the tell. The pruned mode list is fixed at probe time, so something has
# to force a *fresh* probe. On resume that is now automatic: the tb-sleep hook in
# hardware/framework.nix compares each panel's mode count against what it had at
# suspend and software-replugs a degraded one via amdgpu's debugfs
# trigger_hotplug (see ADR 0008). Outside a resume — first plug into a starved
# topology — it is still a physical replug. If a replug doesn't restore it, the
# link genuinely can't carry @144 there and the pin has to come down for that
# profile.
let
  # --- THE QD-OLED'S MOUNT: ONE SWITCH --------------------------------------
  # How that panel physically stands, and the only line to edit to change it:
  #
  #   "portrait"  — on its short edge, rotated −90°, logical 1440x2560. Its top
  #                 edge is then uncomfortably high to read, so the top 810 px
  #                 are a marquee band (docs/adr/0011).
  #   "landscape" — the normal way round, logical 2560x1440, no band.
  #
  # Everything that follows from the mount is derived below: kanshi's
  # `transform`, the panel's logical size, where the portable panel stacks under
  # it in oled-desk-portable, and whether the marquee exists at all. NOTHING
  # else in the tree needs editing — the rice resolves orientation at runtime
  # (Mod+G's even split reads the focused output's geometry — see `evenSplit` in
  # rices/ember/compositors/niri/niri.nix; tofi places itself with percentage `padding-*`, see
  # rices/ember/tofi.nix), and rices/ember/compositors/niri/marquee.nix compiles to nothing when its
  # option is null.
  #
  # Applying a flip: `nh home switch -b backup`, then restart kanshi
  # (`systemctl --user restart kanshi`) or replug the panel — kanshi commits a
  # profile on output changes, not on config reload, so an already-committed
  # rotation otherwise stays up until something re-triggers the profile.
  oledMount = "landscape"; # "portrait" | "landscape"

  # Fail the build on a typo rather than silently landing in landscape.
  oledPortrait =
    if oledMount == "portrait"
    then true
    else if oledMount == "landscape"
    then false
    else throw "monitors.nix: oledMount must be \"portrait\" or \"landscape\", got \"${oledMount}\"";

  # THE panel identity for this monitor, in kanshi's make/model/serial form. The
  # marquee's `panel` is fed from this same binding (below), because the two must
  # be byte-identical — the marquee matches by make/model/serial through niri's
  # IPC, never by connector (see PANEL IDENTITY in rices/ember/compositors/niri/marquee.nix).
  oledPanel = "Micro-Star Int'l Co., Ltd. MAG 272U E16 0x01010101";

  # 3840x2160 at scale 1.5 is 2560x1440 logical; the quarter-turn swaps the two.
  oledLogicalWidth =
    if oledPortrait
    then 1440
    else 2560;
  oledLogicalHeight =
    if oledPortrait
    then 2560
    else 1440;

  # tempest's 4K QD-OLED (MSI MAG 272U E16), as both profiles that drive it want
  # it. Connected DIRECT USB-C (DP-alt / USB4), NOT via the CalDigit dock — full
  # DSC-backed bandwidth and outside the ADR-0008 redock path. HDR/VRR
  # deliberately off. See docs/adr/0009. Match is by make/model/serial, so the
  # DRM connector name is incidental — it moves with the physical port (DP-7 on
  # the old port, DP-2 over USB4).
  #
  # Mode pinned to 3840x2160@165 — the panel's real 4K ceiling once it's on a
  # USB4 port (the earlier @120 cap was the old port's bandwidth; without
  # @refresh niri defaults to the 60Hz preferred mode). If the logical size comes
  # back as the full 3840x2160 (or 2160x3840 rotated) instead of the 1.5-scaled
  # size above, kanshi rejected the fractional scale → move this output to a
  # niri-native `output` block instead.
  #
  # `transform` is set on both mounts rather than omitted in landscape: kanshi
  # leaves an unmentioned property alone, so switching back has to actively
  # un-rotate a panel a previous profile already turned. niri counts transforms
  # COUNTER-clockwise, so 270 is a −90° (clockwise quarter-turn) rotation; "90"
  # is the other way up.
  oledOutput = {
    criteria = oledPanel;
    mode = "3840x2160@165.000";
    position = "0,0";
    scale = 1.5;
    transform =
      if oledPortrait
      then "270"
      else "normal";
  };
in {
  # Machine policy: the QD-OLED carries the marquee (docs/adr/0011), and it does
  # so *because* of how the panel is mounted — the band's whole purpose is the
  # portrait mount's high top edge. So it is derived from oledMount rather than
  # set independently, and standing the panel back up removes it: null means this
  # machine has no marquee and none of rices/ember/compositors/niri/marquee.nix exists.
  #
  # 16:9 of a 2560-wide landscape panel would be 1440 deep — the entire screen —
  # so the arithmetic agrees with the ergonomics. The rice derives the depth from
  # `width`; nothing else needs it.
  rices.ember.marquee =
    if oledPortrait
    then {
      panel = oledPanel;
      width = oledLogicalWidth;
    }
    else null;

  services.kanshi = {
    enable = true;
    systemdTarget = "graphical-session.target";
    settings = [
      {
        profile = {
          name = "docked";
          outputs = [
            {
              # Left unpinned on purpose (→ preferred 2560x1440@60), unlike the
              # other profiles: here the portable shares the CalDigit TS3 Plus's
              # DP 1.2 link with the Samsung 3440x1440, and 1440p@144 alongside
              # it does not fit in HBR2. Pinning @144 would just abort the
              # profile — see the header note.
              criteria = "BOE Display Unknown";
              position = "440,1440";
              scale = 1.0;
            }

            {
              criteria = "Samsung Electric Company S34J55x H4LT300008";
              mode = "3440x1440";
              position = "0,0";
              scale = 1.0;
            }

            {
              criteria = "eDP-1";
              status = "disable";
            }
          ];
        };
      }

      {
        profile = {
          name = "lg-office";
          outputs = [
            {
              criteria = "eDP-1";
              status = "enable";
              mode = "2880x1920@120.000";
              position = "0,0";
              scale = 2.0; # Niri only accepts integer scaling on this panel
            }

            {
              criteria = "LG Electronics LG FHD 0x0004BE08";
              mode = "1920x1080@100.000";
              position = "1440,0";
              scale = 1.0;
            }
          ];
        };
      }

      {
        profile = {
          name = "portable-and-integrated";
          outputs = [
            {
              criteria = "eDP-1";
              status = "enable";
              mode = "2880x1920@120.000";
              position = "0,0";
              # scale = 2.0; # Niri only accepts integer scaling on this panel
            }

            {
              # 1440 = eDP-1's logical width (2880 at the effective 2.0 scale),
              # so the portable panel sits flush to the right of the laptop.
              # @144 untested in this topology (it is verified in
              # oled-desk-portable); the portable is the only external here, so
              # it has a link to itself. If this profile ever aborts on "doesn't
              # support mode", drop the refresh — see the header note.
              criteria = "BOE Display Unknown";
              mode = "2560x1440@144.000";
              position = "1440,0";
              scale = 1.0;
            }
          ];
        };
      }

      {
        profile = {
          name = "mobile";
          outputs = [
            {
              criteria = "eDP-1";
              status = "enable";
              mode = "2880x1920@120.000";
              position = "0,0";
              # scale = 2.0; # Niri only accepts integer scaling on this panel
            }
          ];
        };
      }

      {
        profile = {
          name = "samsung-office";
          outputs = [
            {
              criteria = "Samsung Electric Company S34CG50 HNTX500018";
              mode = "3440x1440@100.000";
              position = "0,0";
              scale = 1.0;
            }
            {
              criteria = "eDP-1";
              status = "disable";
            }
          ];
        };
      }

      {
        # The QD-OLED as the solo clamshell display: lid closed, eDP-1 off, OLED
        # the only output. The panel's own settings — mode, scale, rotation — are
        # `oledOutput` in the let block above; so is the mount switch that decides
        # whether it runs portrait or landscape. Placed ABOVE external-only /
        # fallback so it wins (kanshi applies the first matching profile in file
        # order).
        profile = {
          name = "oled-desk";
          outputs = [
            oledOutput
            {
              criteria = "eDP-1";
              status = "disable";
            }
          ];
        };
      }

      {
        # oled-desk plus the portable 2560x1440 panel stacked BELOW the OLED.
        # kanshi matches the connected set exactly, so oled-desk (MSI + eDP-1)
        # can't cover this three-output case — hence a separate profile.
        # Geometry: the portable's y is the OLED's logical height, so it sits
        # directly under it, flush on the LEFT edge. In the portrait mount the
        # OLED is 1440 logical wide, so the 2560-wide portable overhangs it to the
        # right; in landscape the two are the same logical width and line up
        # exactly. Lid stays closed (eDP-1 off), same as oled-desk.
        #
        # Both externals at full rate is the intent. If the portable comes up at
        # 640x480 (see the header note — its modes got pruned at probe time), the
        # two are likely sharing one starved DP tunnel: dropping the OLED back to
        # @120 frees bandwidth, and replugging the portable onto its own port
        # rather than the CalDigit TS3 Plus forces a fresh probe. The OLED's mode
        # is shared with oled-desk now, so drop it for THIS profile only with
        # `oledOutput // {mode = "3840x2160@120.000";}` in place of `oledOutput`.
        profile = {
          name = "oled-desk-portable";
          outputs = [
            oledOutput
            {
              criteria = "BOE Display Unknown";
              mode = "2560x1440@144.000";
              position = "0,${toString oledLogicalHeight}";
              scale = 1.0;
            }
            {
              criteria = "eDP-1";
              status = "disable";
            }
          ];
        };
      }

      {
        # Internal panel + exactly one external (any unrecognized monitor):
        # drive the external and switch the laptop screen off. `*` matches a
        # single output, so this profile only applies when eDP-1 plus one other
        # display are connected. Must stay below the named two-output profiles
        # (lg-office, portable-and-integrated) so those win for their specific
        # monitors — kanshi applies the first matching profile in file order.
        profile = {
          name = "external-only";
          outputs = [
            {
              criteria = "eDP-1";
              status = "disable";
            }
            {
              criteria = "*";
              status = "enable";
            }
          ];
        };
      }

      {
        profile = {
          name = "fallback";
          outputs = [
            {
              criteria = "*";
              status = "enable";
            }
          ];
        };
      }
    ];
  };
}
