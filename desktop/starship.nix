# starship prompt, shared by the tempest and orchid homes. Managed via HM
# (enableFishIntegration handles the fish hook) rather than a manual
# `starship init` in misc/fish.nix, which double-initialised it on hosts that
# also enabled programs.starship.
{...}: {
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = false;
      # The hostname always, not only over ssh: with two machines running the
      # same shell config, it's the one way to tell them apart at a glance.
      format = "$hostname$all";
      hostname = {
        ssh_only = false;
        format = "[$hostname]($style) ";
        style = "bold green";
      };

      # The right prompt is a readout column: flush-right, glanced at, never
      # read as prose. Both modules are off by default in starship and so are
      # absent from `$all` above — `status` prints only when non-zero, which
      # is the point (a failure that scrolled off is otherwise invisible), and
      # `time` makes scrollback answer "when did this run", including in a log
      # paste. On tempest it isn't redundant with the bar's clock either,
      # because the bar auto-hides for burn-in (ADR 0009).
      #
      # Styles are ANSI names, never hexes: the palette is the terminal's
      # (ember's on tempest, the client's over ssh to orchid).
      right_format = "$status$time";
      status = {
        disabled = false;
        format = "[$status]($style) ";
        style = "bold red";
      };
      time = {
        disabled = false;
        format = "[$time]($style)";
        time_format = "%H:%M:%S";
        style = "bright-black";
      };
    };
  };
}
