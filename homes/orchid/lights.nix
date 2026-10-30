# Machine policy: the desk light strip sleeps and wakes with the monitors.
#
# `lights` drives a Tapo L930 taped around this desk's perimeter. That is a fact
# about one desk, not about the desktop, so it lives here rather than in
# rices/ember — the rice knows no hostnames and owns no furniture that only
# exists in this room. `services.swayidle.timeouts` is a list option, so this
# entry MERGES with the rice's own and it stays unaware a light is listening.
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
  # unreachable plug would wedge the idle daemon — and the monitors with it —
  # for the whole TCP handshake. `|| true` so a strip off at the wall isn't an
  # error on every idle. The bound is per caller: the before-sleep hook gets a
  # tighter one, since it holds up a suspend.
  lights-cmd = seconds: cmd: "${pkgs.coreutils}/bin/timeout ${toString seconds} ${lights}/bin/${cmd} || true";
in {
  home.packages = [lights];

  # The same 120s as the rice's panels-off timer, so the desk goes dark with the
  # screens and comes back with them — as the lesbian flag, not `lights`' plain
  # base effect. Takes `<binary> <arg>` because the package ships both.
  services.swayidle.timeouts = [
    {
      timeout = 120;
      command = lights-cmd 15 "lights off";
      resumeCommand = lights-cmd 15 "flag lesbian";
    }
  ];

  # Off on the way into a manual suspend too (orchid has no battery, so idle
  # never suspends it). Runs inside swayidle's sleep inhibitor, so 5s: past
  # logind's InhibitDelayMaxSec it suspends regardless. Coming back is left to
  # the resumeCommand above, which only runs if the 120s timer had fired.
  rices.ember.beforeSleepCommands = [(lights-cmd 5 "lights off")];
}
