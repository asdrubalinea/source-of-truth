{
  inputs,
  pkgs,
  ...
}: let
  openlogi = inputs.openlogi.packages.${pkgs.stdenv.hostPlatform.system}.openlogi;
in {
  # OpenLogi — local-first replacement for Logitech Options+ (button remapping,
  # DPI, report rate) over HID++. Complements `hardware.logitech.wireless.enable`,
  # which only handles the Unifying/Bolt receiver pairing side.
  #
  # From the flake input, not `pkgs.openlogi`: nixpkgs is on 0.6.25 on every
  # branch, and tempest's receiver — a Lightspeed 046d:c547 fronting a G502 X —
  # only entered `receiver/unifying.rs` VPID_PAIRS in 0.6.27 (#574). On 0.6.25
  # `detect()` skips the receiver, the probe fails ("node probe keeps failing")
  # and only the webcam enumerates, since cameras go through V4L2 and never
  # touch HID++.
  #
  # These three declarations rather than `inputs.openlogi.nixosModules.default`,
  # which exists only on master: it landed in d5d3a7e5 (2026-08-16), after the
  # v0.7.1 tag we pin. Upstream's module is these same declarations. Once a
  # release carries both the module and a master-side GUI fix (see flake.nix),
  # this file collapses to importing it.
  environment.systemPackages = [openlogi];

  # 70-openlogi.rules TAG+="uaccess" on the Logitech hidraw nodes, on their
  # ID_INPUT_MOUSE event nodes (logind's seat rules miss Bluetooth mice, which
  # hang off /devices/virtual/misc/uhid and belong to no seat) and on
  # /dev/uinput. Without them every device operation needs root, and button
  # remapping — which runs through the evdev/uinput hook, not HID++ — can't
  # grab or inject at all.
  services.udev.packages = [openlogi];

  # The agent owns all device I/O; the GUI (`openlogi-gui`) and CLI (`openlogi`)
  # are IPC clients. The package does ship this unit, but in lib/systemd/user
  # with no install section, so it still needs the wantedBy — declaring it
  # outright is what upstream's own module does.
  systemd.user.services.openlogi-agent = {
    description = "OpenLogi background agent";
    wantedBy = ["graphical-session.target"];
    after = ["graphical-session.target"];
    partOf = ["graphical-session.target"];

    serviceConfig = {
      ExecStart = "${openlogi}/bin/openlogi-agent";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # What this mouse actually supports: DPI (0x2201), report rate (0x8060),
  # scroll inversion (0x2121), battery (0x1004) and hook-based remapping. Not
  # SmartShift (0x2110/0x2111 absent — the G502's ratchet is mechanical) and not
  # the onboard profiles it keeps its own DPI stages in (0x8100 is named in
  # feature/registry.rs but unimplemented, so an onboard profile can reassert
  # DPI over what OpenLogi writes). Per-app profile switching is X11-only, so it
  # does nothing under niri.
}
