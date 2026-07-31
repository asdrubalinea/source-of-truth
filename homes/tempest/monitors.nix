{ ... }:
# Machine policy for tempest: monitor identities and layout. These are per-host
# facts (specific BOE/Samsung/LG panel serials and their modes/positions), not
# part of the niri rice — a rice describes "what the desktop is", independent of
# the machine it runs on. Factored out of rices/niri so the rice stays portable.
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
{
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
        # tempest's 4K QD-OLED (MSI MAG 272U E16) as the solo clamshell display:
        # lid closed, eDP-1 off, OLED the only output. Connected DIRECT USB-C
        # (DP-alt / USB4), NOT via the CalDigit dock — full DSC-backed bandwidth
        # and outside the ADR-0008 redock path. scale 1.5 → logical 2560x1440.
        # HDR/VRR deliberately off. See docs/adr/0009. Match is by make/model/
        # serial, so the DRM connector name is incidental — it moves with the
        # physical port (DP-7 on the old port, DP-2 over USB4).
        #
        # Mode pinned to 3840x2160@165 — the panel's real 4K ceiling once it's on
        # a USB4 port (the earlier @120 cap was the old port's bandwidth; without
        # @refresh niri defaults to the 60Hz preferred mode). If the logical size
        # reads 3840x2160 instead of 2560x1440, kanshi rejected the fractional
        # 1.5 scale → move this output to a niri-native `output` block instead.
        # Placed ABOVE external-only / fallback so it wins (kanshi applies the
        # first matching profile in file order).
        profile = {
          name = "oled-desk";
          outputs = [
            {
              criteria = "Micro-Star Int'l Co., Ltd. MAG 272U E16 0x01010101";
              mode = "3840x2160@165.000";
              position = "0,0";
              scale = 1.5;
            }
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
        # Geometry: the OLED's logical size is 2560x1440 (3840x2160 at scale
        # 1.5), so the portable — native 2560x1440 at scale 1.0 — aligns flush
        # on both side edges, and y=1440 is exactly the OLED's logical height.
        # Lid stays closed (eDP-1 off), same as oled-desk.
        #
        # Both externals at full rate is the intent. If the portable comes up at
        # 640x480 (see the header note — its modes got pruned at probe time), the
        # two are likely sharing one starved DP tunnel: dropping the OLED back to
        # @120 here frees bandwidth, and replugging the portable onto its own
        # port rather than the CalDigit TS3 Plus forces a fresh probe.
        profile = {
          name = "oled-desk-portable";
          outputs = [
            {
              criteria = "Micro-Star Int'l Co., Ltd. MAG 272U E16 0x01010101";
              mode = "3840x2160@165.000";
              position = "0,0";
              scale = 1.5;
            }
            {
              criteria = "BOE Display Unknown";
              mode = "2560x1440@144.000";
              position = "0,1440";
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
