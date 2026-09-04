# The instrument panel: `sitrep` in a floating terminal, bound to Mod+I by both
# compositor layers, which is why it lives up here beside ./play-clipboard.nix
# rather than inside one of them (ADR 0012).
#
# NOT a bar widget, deliberately. docs/ember-visual-language.md rejects an
# always-on telemetry panel twice over — the bar auto-hides for burn-in
# (ADR 0009), so a permanent readout contradicts the rice's own mitigation, and
# noctalia v5 can no longer poll a script (ADR 0003). A keybind answers the same
# question with the opposite lifetime: nothing is lit until asked for, and the
# numbers are true at the moment you look rather than a poll interval stale.
# This is principle 3 ("nothing is lit that doesn't have to be") applied to the
# one readout the desktop actually wanted.
#
# Deliberately unprivileged. `sitrep` needs root only for the SMART section and
# says so in place of printing zeroes; a HUD that opens a password prompt is no
# longer a glance.
{pkgs}: let
  sitrep = pkgs.callPackage ../../packages/sitrep.nix {};

  # Held open after the readout: the process exiting closes the window, and a
  # one-screen report that disappears on completion is not a report. Any key
  # dismisses. `read` is what makes this need a script at all — neither
  # compositor spawns through a shell (see ./play-clipboard.nix).
  hold = pkgs.writeShellScript "ember-sitrep-hold" ''
    ${sitrep}/bin/sitrep
    printf '\n  [any key to dismiss]'
    read -rsn1
  '';
in
  # --always-new-process for the same reason the terminal scratchpad uses it: a
  # plain `wezterm start` hands the window to an already-running instance, which
  # stamps it with *that* instance's app-id and the window rule never matches.
  pkgs.writeShellScript "ember-sitrep-hud" ''
    exec ${pkgs.wezterm}/bin/wezterm start --always-new-process --class sitrep-hud -- ${hold}
  ''
