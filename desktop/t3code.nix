# T3 Code (https://t3.codes): the desktop app, its themes, settings and keys.
# The app is an Electron front-end over the agent CLIs in ./cli-packages.nix,
# which it finds on PATH. Orchid adds a server on top: homes/orchid/t3code.nix.
#
# Everything below the package applies to every T3 home on this machine: ~/.t3
# (the desktop app's own on tempest, the lingering server on orchid) and
# ~/.t3-desktop (orchid's app).
#
# T3 rewrites these files from its own UI and refuses a symlinked theme, so
# nothing links into the store: activation copies the theme and merges the
# JSON in two tiers. `managed` follows the rice and wins on every activation.
# `defaults` only fills keys that are missing, so they set up a new machine
# without undoing a later change made in the UI.
#
# The integrated terminal already runs fish (T3 spawns $SHELL), so starship and
# stylix's base16 palette come from the usual fish config. What T3 decides is
# the drawer's ground, cursor, selection and font, set below.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  c = config.lib.stylix.colors.withHashtag;
  fonts = config.stylix.fonts;

  # One <id>.json per entry in T3's theme picker. T3 derives every surface it
  # is not given, the terminal's included, from `canvas`, tinted toward
  # `accent`. No id may be "ember": that is a reserved T3 built-in, and the
  # loader skips it.
  themes = {
    # Not the rice's pure-black base00: the plum ground is T3 Chat's dark
    # canvas, and the accent is the rice's magenta.
    ember-pink = {
      name = "Ember Pink";
      canvas = "#1f1a24";
      accent = c.base0E;
      colors = {
        # Near-white rather than the rice's cream, for contrast on the plum.
        text = "#f9f8fb";
        textMuted = "#e7d0dd";
        error = c.base08;
        warning = c.base0A;
        terminalForeground = "#f9f8fb";
        terminalCursor = c.base0E;
      };
    };
    # The rice as it is everywhere else: black ground, cream text, the orange
    # ember as accent. The one to pick on an OLED.
    ember-3400k = {
      name = "Ember 3400K";
      canvas = c.base00;
      accent = c.base09;
      colors = {
        text = c.base05;
        textMuted = c.base04;
        error = c.base08;
        warning = c.base0A;
        terminalBackground = c.base00;
        terminalForeground = c.base05;
        terminalCursor = c.base05;
        terminalSelection = c.base03;
      };
    };
  };
  defaultTheme = "ember-pink";
  themeJSON = id:
    builtins.toJSON ({
        version = 1;
        appearance = "dark";
      }
      // themes.${id});

  server = {
    managed = {
      # Connected clients, tempest's included, switch to the environment's
      # theme. They reapply it only when the stamp changes, so the stamp is the
      # theme's hash: a palette change is pushed again, and otherwise a theme
      # picked by hand is left alone.
      inherit defaultTheme;
      defaultThemeSetAt = builtins.hashString "sha256" (themeJSON defaultTheme);
    };
    defaults = {
      defaultModelSelection = {
        instanceId = "claudeAgent";
        model = "claude-opus-5-5";
      };
      fallbackModelSelection = {
        instanceId = "claudeAgent";
        model = "claude-sonnet-5-5";
      };
      defaultRuntimeMode = "auto";
      idleCompaction = "onReturn";
      autoResumeLimitedThreads = true;
      sidebarAutoSettleKeepPullRequests = true;
      branchNamePrefix = "";
    };
  };

  client = {
    managed = {
      fontFamilySans = fonts.sansSerif.name;
      fontFamilyCode = fonts.monospace.name;
      fontFamilyTerminal = fonts.monospace.name;
      # The stylix number as is. Converting points to CSS px (x4/3) rendered far
      # larger than kitty at the same setting.
      fontSizeTerminal = fonts.sizes.terminal;
    };
    defaults = {
      appearanceContrast = 200;
      glassOpacity = 65;
    };
  };

  # A command listed in keybindings.json replaces all of T3's default bindings
  # for it, and T3 refills the commands left out, so these replace only their
  # own commands. `mod` is Ctrl here, and T3's defaults are Cmd-on-macOS ones:
  # in the terminal they took Ctrl+D (EOF), Ctrl+W (delete word) and Ctrl+N
  # (next history) from the shell. They move to Ctrl+Shift, as in kitty.
  keybindings = [
    {
      key = "mod+shift+d";
      command = "terminal.split";
      when = "terminalFocus";
    }
    {
      key = "mod+alt+d";
      command = "terminal.splitVertical";
      when = "terminalFocus";
    }
    {
      key = "mod+shift+n";
      command = "terminal.new";
      when = "terminalFocus";
    }
    {
      key = "mod+shift+w";
      command = "terminal.close";
      when = "terminalFocus";
    }
    # Ctrl+J is T3's own toggle, kept beside Ctrl+Shift+Enter.
    {
      key = "mod+j";
      command = "terminal.toggle";
    }
    {
      key = "mod+shift+enter";
      command = "terminal.toggle";
    }
    # Its default was Ctrl+Shift+Enter, which now toggles the terminal.
    {
      key = "mod+alt+shift+enter";
      command = "thread.steerQueuedMessage";
      when = "!terminalFocus";
    }
  ];

  installThemes = lib.concatMapStrings (id: ''
    run install -Dm644 ${pkgs.writeText "${id}.json" (themeJSON id)} "$ud/themes/${id}.json"
  '') (lib.attrNames themes);

  arg = v: lib.escapeShellArg (builtins.toJSON v);
in {
  # llm-agents over nixpkgs' t3code for the same reason as codex: it tracks
  # upstream closer.
  home.packages = [inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.t3code-desktop];

  # stylix's base16 fish script also sets the terminal ground (OSC 11) to the
  # rice's black, which would repaint T3's terminal over the theme. Every
  # terminal stylix themes already sets its own ground, so nothing loses it.
  # shellInit, not a session variable: it runs before the interactive block
  # that calls the script, in every fish, whatever env it inherited.
  programs.fish.shellInit = "set -g BASE16_SHELL_SET_BACKGROUND false";

  home.activation.t3code = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # t3edit FILE FILTER A B: rewrite FILE through a jq FILTER over $a and $b.
    t3edit() {
      local f=$1 tmp
      tmp=$(mktemp "$f.XXXXXX")
      if { if [ -s "$f" ]; then cat "$f"; else echo '{}'; fi; } \
        | ${pkgs.jq}/bin/jq --argjson a "$3" --argjson b "$4" "$2" >"$tmp"; then
        if [ -e "$f" ]; then chmod --reference="$f" "$tmp"; else chmod 644 "$tmp"; fi
        mv "$tmp" "$f"
      else
        rm -f "$tmp"
        echo "t3code: $f is not valid JSON, left as is" >&2
      fi
    }

    # Settings: defaults under the file, managed keys over it.
    merge='$a * . * $b'
    # Keybindings: drop every rule for a managed command, then add ours.
    rebind='($a | map(.command)) as $cs | map(select(.command as $c | $cs | index($c) | not)) + $a'

    for t3home in "$HOME/.t3" "$HOME/.t3-desktop"; do
      ud=$t3home/userdata
      [ -d "$ud" ] || continue
      ${installThemes}
      run t3edit "$ud/settings.json" "$merge" ${arg server.defaults} ${arg server.managed}
      # Only where a desktop app already keeps its client settings, which
      # leaves orchid's server-only ~/.t3 without one.
      if [ -e "$ud/client-settings.json" ]; then
        run t3edit "$ud/client-settings.json" "$merge" ${arg client.defaults} ${arg client.managed}
      fi
      # Only once T3 has written its defaults here; an empty file would hold
      # nothing but these until the server backfilled the rest.
      if [ -e "$ud/keybindings.json" ]; then
        run t3edit "$ud/keybindings.json" "$rebind" ${arg keybindings} null
      fi
    done
  '';
}
