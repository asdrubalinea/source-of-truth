{ ... }:
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
              criteria = "PNP(BNQ) BenQ GW2765 W6H00193019";
              mode = "2560x1440";
              position = "3440,0";
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
          name = "mobile";
          outputs = [
            {
              criteria = "eDP-1";
              mode = "2880x1920";
              position = "0,0";
              scale = 1.5;
            }
            {
              criteria = "*";
              status = "disable";
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
