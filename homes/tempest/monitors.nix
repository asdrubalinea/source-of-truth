{ ... }:
# Machine policy for tempest: monitor identities and layout. These are per-host
# facts (specific BOE/Samsung/LG panel serials and their modes/positions), not
# part of the niri rice — a rice describes "what the desktop is", independent of
# the machine it runs on. Factored out of rices/niri so the rice stays portable.
# See the "machine policy" entry in CONTEXT.md and docs/adr/0004.
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
              criteria = "BOE Display Unknown";
              mode = "2560x1440";
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
              criteria = "BOE Display Unknown";
              mode = "2560x1440";
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
        # tempest's 4K QD-OLED (MSI MAG 272UP E16, 3840x2160@165) as the solo
        # clamshell display: lid closed, eDP-1 off, OLED the only output.
        # Connected DIRECT USB-C (DP-alt), NOT via the CalDigit dock — full
        # DSC-backed bandwidth and outside the ADR-0008 redock path. scale 1.5 →
        # logical 2560x1440. HDR/VRR deliberately off. See docs/adr/0009.
        #
        # SCAFFOLD — the panel isn't here yet. On first connect, fill the two
        # TODOs from `niri msg outputs`, then verify the logical size reads
        # 2560x1440 (fractional scale honored via kanshi). If it still reads
        # 3840x2160, kanshi's fractional scale was rejected → move this output to
        # a niri-native `output` block instead. Placed ABOVE external-only /
        # fallback so it wins (kanshi applies the first matching profile in file
        # order). Until the criteria below is completed this profile stays inert
        # and the OLED falls through to external-only at scale 1.0 (tiny).
        profile = {
          name = "oled-desk";
          outputs = [
            {
              # TODO(on arrival): exact make/model/serial from `niri msg outputs`,
              # e.g. "MSI MAG 272UP QD-OLED <serial>".
              criteria = "MSI MAG 272UP QD-OLED";
              # TODO(on arrival): exact mode incl. refresh to 3 decimals, e.g.
              # "3840x2160@165.000". Without @refresh niri may pick 60Hz — pin it.
              mode = "3840x2160";
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
