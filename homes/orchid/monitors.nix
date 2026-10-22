{...}:
# Machine policy for orchid: monitor identities and layout. Per-host facts, not
# part of the ember rice — same split as homes/tempest/monitors.nix (ADR 0004).
#
# The panel is the MSI MAG 272U, the same 27" 4K QD-OLED that tempest's
# oledOutput describes, driven here by the 9070 XT. Its EDID preferred timing is
# 3840x2160@60, so without the `mode` pin both compositors bring it up at 60Hz
# and scale 1 — the right resolution, at a quarter of the panel's rate and with
# everything tiny. If kanshi ever logs "doesn't support mode", the link probed
# degraded; replug rather than dropping the pin.
#
# The portable BOE is tempest's too, and pinned for the same reason: its EDID
# prefers 2560x1440@60 though the panel does 144. kanshi commits atomically and
# does not fall through, so a rejected pin aborts the whole desk-portable
# profile — the OLED included — rather than just the portable.
#
# kanshi commits on output changes, not on config reload: after a switch,
# `systemctl --user restart kanshi` (or replug) to apply an edit here.
let
  # Matched by make/model/serial, so the connector name is incidental.
  # 3840x2160 at 1.5 is 2560x1440 logical, as on tempest. HDR/VRR deliberately
  # left alone (ADR 0009).
  oledOutput = {
    criteria = "Micro-Star Int'l Co., Ltd. MAG 272U E16 0x01010101";
    mode = "3840x2160@165.000";
    position = "0,0";
    scale = 1.5;
  };

  # The OLED's logical height at scale 1.5, i.e. where the portable stacks.
  oledLogicalHeight = 1440;
in {
  # The bus-powered portable BOE cannot be DPMS-slept — cutting its DP signal
  # drops it off the bus and it reconnects a second later, lit. Its scaler does
  # honour VCP D6 over DDC, so panels-off drives it through ddcutil instead
  # (i2c is enabled in hosts/orchid/hardware.nix). The id is ddcutil's
  # MFG:model:serial, and this panel reports no serial, so the trailing colon is
  # part of the id. Same as homes/tempest/monitors.nix.
  rices.ember.ddcSleepMonitors = ["BOE:Display:"];

  services.kanshi = {
    enable = true;
    systemdTarget = "graphical-session.target";
    settings = [
      {
        profile = {
          name = "desk";
          outputs = [oledOutput];
        };
      }

      {
        # desk plus the portable stacked BELOW the OLED, flush on the left edge
        # — tempest's oled-desk-portable, less the lid panel. kanshi matches the
        # connected set exactly, so desk can't cover the two-output case.
        #
        # If the portable comes up at 640x480 its modes got pruned at probe
        # time: replug it to force a fresh probe. If a replug doesn't restore
        # @144, the link can't carry it and the refresh pin has to come down.
        profile = {
          name = "desk-portable";
          outputs = [
            oledOutput
            {
              # Glob, not "Unknown": the EDID has an empty serial string but a
              # binary serial of 0x144. niri reports the former ("Unknown"),
              # mango/wlroots the latter ("0x00000144"), and this profile has to
              # match under both compositors.
              criteria = "BOE Display *";
              mode = "2560x1440@144.000";
              position = "0,${toString oledLogicalHeight}";
              scale = 1.0;
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
