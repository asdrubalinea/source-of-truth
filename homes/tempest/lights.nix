# Machine policy: the desk light strip follows the idle timers.
#
# `lights` drives a Tapo L930 taped around this desk's perimeter. That is a fact
# about one desk, not about the desktop, so it lives here rather than in
# rices/ember — the rice knows no hostnames and owns no furniture that only
# exists in this room. `services.swayidle.timeouts` is a list option, so these
# entries MERGE with the rice's own and it stays unaware a light is listening.
#
# Credentials are out of band per the repo's convention: TAPO_USERNAME /
# TAPO_PASSWORD / TAPO_IP in ~/.config/lights/env, the fixed path connect()
# reads (a user service has no working directory to find a .env in).
{
  inputs,
  pkgs,
  ...
}: let
  lights = pkgs.callPackage "${inputs.lights}/package.nix" {};

  # Absolute store path, as every swayidle command here must be. The bound is
  # the part the compositor-local commands don't need: the strip is a wifi
  # device across a router and swayidle runs commands synchronously, so an
  # unreachable plug would wedge the idle daemon for the whole TCP handshake.
  # `|| true` so a strip off at the wall isn't an error every 120s. The bound is
  # per caller — the before-sleep hook gets a tighter one, since it holds up a
  # suspend. Takes the whole `<binary> <arg>` because the package ships both
  # `lights` and `flag`.
  #
  # Ceiling: resume races wifi association, so the strip may stay dark until the
  # next manual `lights`. Not worth a retry loop for a desk lamp.
  lights-cmd = seconds: cmd: "${pkgs.coreutils}/bin/timeout ${toString seconds} ${lights}/bin/${cmd} || true";
in {
  home.packages = [lights];

  services.swayidle.timeouts = [
    {
      # The same 120s as the rice's panels-off timer, so the room dims with the
      # screens rather than a beat after. This resume also covers the `off`
      # below — swayidle runs the resumeCommand of every timeout that fired.
      # `flag` rather than `lights on` because it starts from the same depth
      # mask, so the near edge is still the dimmest thing on the desk.
      timeout = 120;
      command = lights-cmd 15 "lights dim";
      resumeCommand = lights-cmd 15 "flag lesbian";
    }
    {
      # The *awake* path only: on AC the box never suspends itself, so this is
      # what darkens the desk overnight while plugged in. It cannot be the sleep
      # path — suspend stops the idle clock, so a lid close at 130s idle left
      # the strip at the dim level all night with this timer never counting down.
      timeout = 900;
      command = lights-cmd 15 "lights off";
    }
  ];

  # Off on the way into suspend, whatever the timers had reached. Runs inside
  # swayidle's sleep inhibitor, so 5s: past logind's InhibitDelayMaxSec it
  # suspends regardless and the call would be frozen mid-TCP anyway.
  #
  # Coming back is left to the 120s resumeCommand, i.e. real user activity, NOT
  # logind's resume — with the lid closed this machine wakes on a spurious GPE
  # every ~41s and re-suspends, and lighting the desk on each would leave the
  # strip on all night. Cost: a lid closed while genuinely active (no timer
  # fired, so none to resume) reopens onto a dark desk.
  rices.ember.beforeSleepCommands = [(lights-cmd 5 "lights off")];
}
