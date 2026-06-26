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
              criteria = "BOE Display Unknown";
              mode = "2560x1440";
              position = "0,0";
              scale = 1.0;
            }

            {
              criteria = "eDP-1";
              status = "enable";
              mode = "2880x1920@120.000";
              position = "2560,0";
              # scale = 2.0; # Niri only accepts integer scaling on this panel
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
