# Nearest-flight radar server (github:asdrubalinea/flights). The HM module runs
# flights-server as a systemd user service tied to graphical-session.target (one
# always-on poller — a client never starts its own) and puts the `flights` (TUI)
# and `flights-waybar` clients on PATH. Nothing on the desktop reads it anymore:
# the bar widget it used to feed went away with waybar in the Noctalia migration
# (ADR 0003), and Noctalia v5 can't poll a script. The TUI is the interface now.
#
# Set [home] lat/lon in ~/.config/flights/config.toml so distances measure from
# here; everything else has sane defaults.
#
# web.enable also serves the compiled static webclient (the .#web-dist bundle)
# over a static-web-server user service at http://127.0.0.1:8080, wiring the
# Server's --cors-allow-origin to match. Defaults are loopback-only; set
# web.address / web.corsOrigin to reach it from the LAN.
{ inputs, ... }:
{
  imports = [ inputs.flights.homeManagerModules.default ];

  services.flights-server = {
    enable = true;
    web.enable = true;
  };
}
