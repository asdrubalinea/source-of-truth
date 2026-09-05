# Machine policy: the desk light strip follows the idle timers.
#
# `lights` (github:asdrubalinea/lights) drives a Tapo L930 taped around the
# perimeter of this desk — near edge dim, far edge bright, `dim` for an idle
# level and `off` to kill it. That is a fact about one desk, not about the
# desktop, so it lives here rather than in rices/ember: the rice knows no
# hostnames and owns no furniture that only exists in this room.
#
# `services.swayidle.timeouts` is a list option, so these entries MERGE with the
# rice's own (rices/ember/swayidle.nix) instead of replacing them — no rice
# option needed, and the rice stays unaware a light is listening to its timers.
#
# Credentials are out of band, per the repo's secrets convention: put
# TAPO_USERNAME / TAPO_PASSWORD / TAPO_IP in ~/.config/lights/env (the fixed
# path connect() reads, since a user service has no working directory to find a
# .env in). Home is persisted, so that file survives a reboot.
{
  inputs,
  pkgs,
  ...
}: let
  lights = pkgs.callPackage "${inputs.lights}/package.nix" {};

  # Same rules as every other swayidle command in this config: an absolute store
  # path, because swayidle inherits the systemd user-manager PATH and has no
  # coreutils on it. Plus a bound, which the compositor-local commands don't
  # need — the strip is a wifi device on the far side of a router, and swayidle
  # runs each command synchronously, so an unplugged or unreachable plug would
  # otherwise wedge the idle daemon for as long as the TCP handshake takes.
  # `|| true` so a strip that's off at the wall is not an error every 120s.
  #
  # Ceiling: resuming from suspend races wifi association, so the strip may stay
  # dark until the next manual `lights`. Not worth a retry loop for a desk lamp.
  #
  # Takes the whole `<binary> <arg>`, because the package ships more than one:
  # `lights` for the plain warm levels, `flag` for the pride stripes.
  lights-cmd = cmd: "${pkgs.coreutils}/bin/timeout 15 ${lights}/bin/${cmd} || true";
in {
  home.packages = [lights];

  services.swayidle.timeouts = [
    {
      # The same 120s as the rice's panels-off timer, so the room dims with the
      # screens rather than a beat after them. Resume brings it straight back
      # up — that resume also covers the `off` below, since swayidle runs the
      # resume command of every timeout that had fired.
      #
      # Coming back is the lesbian flag rather than `lights on`: `flag` starts
      # from the same depth mask, so the near edge is still the dimmest thing
      # on the desk — it just isn't the house near-white any more.
      timeout = 120;
      command = lights-cmd "lights dim";
      resumeCommand = lights-cmd "flag lesbian";
    }
    {
      # A quarter of an hour dim and the desk is genuinely unoccupied: go dark.
      # Sits between the idle lock (600s) and the on-battery suspend (1200s),
      # so on battery the strip is already off before the box drops to s2idle.
      timeout = 900;
      command = lights-cmd "lights off";
    }
  ];
}
