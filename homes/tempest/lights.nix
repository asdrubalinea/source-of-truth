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
  # Takes the bound and the whole `<binary> <arg>`, because the package ships
  # more than one: `lights` for the plain warm levels, `flag` for the pride
  # stripes. The bound is per caller — the before-sleep hook below gets a tighter
  # one than the idle timers, since it is holding up a suspend.
  lights-cmd = seconds: cmd: "${pkgs.coreutils}/bin/timeout ${toString seconds} ${lights}/bin/${cmd} || true";
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
      command = lights-cmd 15 "lights dim";
      resumeCommand = lights-cmd 15 "flag lesbian";
    }
    {
      # A quarter of an hour dim and the desk is genuinely unoccupied: go dark.
      # This is the *awake* path only — on AC the box never suspends itself, so
      # this is what darkens the desk overnight while it's plugged in. It cannot
      # be the sleep path: suspend stops the idle clock, so a lid close at 130s
      # idle left the strip sitting at the near-white dim level all night, with
      # the remaining 770s of this timer never counted down. Sleep is an event,
      # and it's hooked as one below.
      timeout = 900;
      command = lights-cmd 15 "lights off";
    }
  ];

  # Off on the way into suspend, whatever the idle timers had reached. Runs
  # inside swayidle's sleep inhibitor (rices/ember/swayidle.nix), so 5s: past
  # logind's InhibitDelayMaxSec it suspends regardless and the call would be
  # frozen mid-TCP anyway.
  #
  # Coming back is left to the 120s timer's resumeCommand, i.e. to real user
  # activity, NOT to logind's resume — with the lid closed this machine wakes on
  # a spurious GPE every ~41s and re-suspends (see the s2idle wake loop), and
  # lighting the desk on each of those would be a strip on all night. The cost
  # is that a lid closed while genuinely active (no timer fired, so none to
  # resume) reopens onto a dark desk until the next idle cycle.
  rices.ember.beforeSleepCommands = [(lights-cmd 5 "lights off")];
}
