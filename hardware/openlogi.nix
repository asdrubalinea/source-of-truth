{
  inputs,
  pkgs,
  ...
}: let
  openlogi = inputs.openlogi.packages.${pkgs.stdenv.hostPlatform.system}.openlogi;
in {
  # OpenLogi — local-first replacement for Logitech Options+ (remapping, DPI,
  # report rate) over HID++. Complements hardware.logitech.wireless.enable,
  # which only does receiver pairing.
  #
  # From the flake input, not pkgs.openlogi: nixpkgs is on 0.6.25 everywhere, and
  # tempest's Lightspeed receiver only entered VPID_PAIRS in 0.6.27 — on 0.6.25
  # `detect()` skips it, the probe fails, and only the webcam enumerates (cameras
  # go through V4L2 and never touch HID++).
  #
  # These three declarations rather than inputs.openlogi.nixosModules.default,
  # which exists only on master, after the rev flake.nix pins. Upstream's module
  # is these same declarations, so once a release carries both it and the
  # master-side GUI fix, this file collapses to importing it.
  environment.systemPackages = [openlogi];

  # TAG+="uaccess" on the Logitech hidraw nodes, their ID_INPUT_MOUSE event
  # nodes (logind's seat rules miss Bluetooth mice, which belong to no seat) and
  # /dev/uinput. Without them every operation needs root, and button remapping —
  # which goes through evdev/uinput, not HID++ — can't grab or inject at all.
  services.udev.packages = [openlogi];

  # The agent owns all device I/O; the GUI and CLI are IPC clients. The package
  # ships this unit but with no install section, so it still needs the wantedBy —
  # declaring it outright is what upstream's own module does.
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

  # Supported on this mouse: DPI, report rate, scroll inversion, battery and
  # hook-based remapping. NOT SmartShift (the G502's ratchet is mechanical) and
  # not onboard profiles, which is where it keeps its own DPI stages —
  # unimplemented upstream, so an onboard profile can reassert DPI over what
  # OpenLogi writes. Per-app switching is X11-only and does nothing under niri.
}
