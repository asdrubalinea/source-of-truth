# Nearest-flight radar server (github:asdrubalinea/flights), backing the
# custom/flights Waybar widget defined in ./waybar/default.nix. The HM module
# runs flights-server as a systemd user service tied to graphical-session.target
# (one always-on poller — the waybar client never starts its own) and puts the
# `flights` (TUI) and `flights-waybar` clients on PATH.
#
# Set [home] lat/lon in ~/.config/flights/config.toml so distances measure from
# here; everything else has sane defaults.
{ inputs, ... }:
{
  imports = [ inputs.flights.homeManagerModules.default ];

  services.flights-server.enable = true;
}
