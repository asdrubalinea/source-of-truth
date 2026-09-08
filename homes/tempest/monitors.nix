{...}:
# Machine policy for tempest: monitor identities and layout. Per-host facts
# (panel serials, modes, positions), not part of the ember rice — a rice
# describes "what the desktop is" independent of the machine. See "machine
# policy" in CONTEXT.md and ADR 0004.
#
# WHY THE MODES ARE PINNED: the portable BOE's EDID preferred timing is
# 2560x1440@60 though the panel does 144 at native res, so the `mode` pin is
# what carries the refresh rate. Drop it and you get the right resolution at
# 60Hz — "correct but feels laggy".
#
# THE COST OF PINNING, and the tell for it: if a panel probes degraded (behind a
# hub, or on a starved DP link) the kernel prunes its mode list, and kanshi logs
#   output '<head>' doesn't support mode '2560x1440@144.000000Hz'
# Because kanshi commits atomically and does NOT fall through to the next
# matching profile, the ENTIRE profile aborts — the OLED reverts to 60Hz and the
# lid panel wakes back up. A pruned mode list is fixed at probe time, so
# something has to force a FRESH probe. On resume that is automatic (the tb-sleep
# hook in hardware/framework.nix software-replugs a degraded panel, ADR 0008);
# otherwise it is a physical replug. If a replug doesn't restore it, the link
# genuinely can't carry @144 there and the pin has to come down for that
# profile.
let
  # --- THE QD-OLED'S MOUNT: ONE SWITCH --------------------------------------
  # How the panel physically stands, and the only line to edit to change it:
  #
  #   "portrait"  — on its short edge, rotated −90°, logical 1440x2560. Its top
  #                 edge is then uncomfortably high to read, so the top 810 px
  #                 are a marquee band (ADR 0011).
  #   "landscape" — the normal way round, logical 2560x1440, no band.
  #
  # Everything else follows: kanshi's transform, the logical size, where the
  # portable stacks under it, and whether the marquee exists at all. NOTHING
  # else in the tree needs editing — the rice resolves orientation at runtime
  # and marquee.nix compiles to nothing when its option is null.
  #
  # To apply a flip: `nh home switch -b backup`, then restart kanshi or replug
  # the panel. kanshi commits on output changes, not on config reload, so an
  # already-committed rotation otherwise stays up.
  oledMount = "landscape"; # "portrait" | "landscape"

  # Fail the build on a typo rather than silently landing in landscape.
  oledPortrait =
    if oledMount == "portrait"
    then true
    else if oledMount == "landscape"
    then false
    else throw "monitors.nix: oledMount must be \"portrait\" or \"landscape\", got \"${oledMount}\"";

  # THE panel identity for this monitor, in kanshi's make/model/serial form. The
  # marquee's `panel` is fed from this same binding because the two must be
  # byte-identical — see PANEL IDENTITY in marquee.nix.
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

  # The 4K QD-OLED, as both profiles that drive it want it. Connected DIRECT
  # USB-C, NOT via the CalDigit dock — full DSC-backed bandwidth, and outside the
  # ADR-0008 redock path. HDR/VRR deliberately off (ADR 0009). Matched by
  # make/model/serial, so the connector name is incidental.
  #
  # @165 is the panel's real 4K ceiling on a USB4 port (the old @120 cap was the
  # previous port's bandwidth). If the logical size comes back as the full
  # 3840x2160 instead of the 1.5-scaled size, kanshi rejected the fractional
  # scale → move this output to a niri-native `output` block.
  #
  # `transform` is set on both mounts rather than omitted in landscape, because
  # kanshi leaves an unmentioned property alone — switching back has to actively
  # un-rotate. niri counts COUNTER-clockwise, so 270 is a clockwise quarter-turn.
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
  # The QD-OLED carries the marquee (ADR 0011) *because* of how it is mounted —
  # the band exists for the portrait mount's high top edge. So it is derived from
  # oledMount rather than set independently, and standing the panel back up
  # removes it: null means no marquee and marquee.nix compiles to nothing.
  # (16:9 of a 2560-wide landscape panel would be 1440 deep — the whole screen —
  # so the arithmetic agrees with the ergonomics.)
  rices.ember.marquee =
    if oledPortrait
    then {
      panel = oledPanel;
      width = oledLogicalWidth;
    }
    else null;

  # The bus-powered portable BOE cannot be DPMS-slept — cutting its DP signal
  # drops it off the bus and it reconnects a second later, lit. Its scaler does
  # honour VCP D6 over DDC, so panels-off drives it through ddcutil instead. The
  # id is ddcutil's MFG:model:serial, and this panel reports no serial, so the
  # trailing colon is part of the id.
  rices.ember.ddcSleepMonitors = ["BOE:Display:"];

  services.kanshi = {
    enable = true;
    systemdTarget = "graphical-session.target";
    settings = [
      {
        profile = {
          name = "docked";
          outputs = [
            {
              # Unpinned on purpose (→ preferred @60), unlike the other
              # profiles: here the portable shares the dock's DP 1.2 link with
              # the Samsung, and 1440p@144 alongside it doesn't fit in HBR2.
              # Pinning would just abort the profile — see the header note.
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
              # 1440 = eDP-1's logical width, so the portable sits flush to
              # the right of the laptop. @144 is untested in this topology but
              # the portable is the only external here, so it has a link to
              # itself. If this profile aborts on "doesn't support mode", drop
              # the refresh.
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
        # Solo clamshell: lid closed, eDP-1 off, OLED the only output. Its own
        # settings are `oledOutput` above. Placed ABOVE external-only/fallback so
        # it wins — kanshi applies the first matching profile in file order.
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
        # oled-desk plus the portable stacked BELOW the OLED. kanshi matches the
        # connected set exactly, so oled-desk can't cover this three-output case
        # — hence a separate profile. The portable's y is the OLED's logical
        # height, so it sits directly under it flush on the LEFT edge (in
        # portrait it overhangs to the right; in landscape they line up).
        #
        # If the portable comes up at 640x480 its modes got pruned at probe time
        # (see the header note) and the two are likely sharing one starved DP
        # tunnel: dropping the OLED to @120 frees bandwidth, and replugging the
        # portable onto its own port forces a fresh probe. The OLED's mode is
        # shared with oled-desk, so override it for THIS profile only with
        # `oledOutput // {mode = "3840x2160@120.000";}`.
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
        # Internal panel + exactly one unrecognized external: drive the
        # external, switch the laptop screen off. `*` matches a single output.
        # Must stay BELOW the named two-output profiles so those win for their
        # specific monitors — first match in file order.
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
