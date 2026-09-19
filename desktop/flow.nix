{
  lib,
  config,
  ...
}:
# Flow Control (packages/flow-git.nix, installed from ./cli-packages.nix).
#
# FLOW OWNS ITS CONFIG FILE. `tui.zig` calls `save_config()` unconditionally at
# the end of startup, so `~/.config/flow/config` is rewritten on EVERY launch,
# not just when a setting is changed interactively. A store symlink there would
# be replaced by a real file the first time flow ran and backed up again on every
# `nh home switch -b backup` — permanent churn.
#
# Upstream's answer, from the header flow writes into that file: put values flow
# must not touch in a separate file and name it in `include_files`, which is read
# after the main config (so these win) and never written back. That is what
# ./flow/generated.json is. `config` stays flow's own mutable file; the
# activation below adds the one line pointing at ours, once. The include path
# must be ABSOLUTE — `read_nested_include_files` opens it with
# `openFileAbsolute` — so it names the ~/.config symlink, not the store path
# behind it, which would go stale on the next rebuild.
#
# The bargain: anything declared here reverts on restart if you change it live
# (the theme picker, f4 cycling the input mode). Anything NOT declared here
# persists the way flow intends.
#
# THE ROLE MAPPING IS ./helix-theme.nix's, not a second visual language. That
# file explains the NANO faces (default / faded / strong / salient / literal /
# popout / critical), why the ramp has two levels and not three, and why
# punctuation and operators are left unmapped rather than tinted — all of it
# applies here unchanged, so only the differences are noted below. Read it first
# if you are about to change a colour.
let
  themed = config.stylix.enable or false;

  includeFile = "${config.xdg.configHome}/flow/generated.json";

  settings =
    {
      # The whole point of the `input_mode` setting, and the only keymap work
      # needed: flow ships vim as a built-in namespace (src/keybind/builtin/
      # vim.json), so there is nothing to author. Flow-mode bindings that don't
      # collide still work, and f4 cycles out of it live.
      input_mode = "vim";

      # Same three as ./helix.nix, for the same reasons: relative numbers, and no
      # current-line fill. base01 is 6/255 above the ground, so that fill lights
      # a row on every keystroke and shows nothing the block cursor and the bold
      # active line number don't already say.
      gutter_line_numbers_mode = "relative";
      highlight_current_line = false;
      highlight_current_line_gutter = false;

      # helix's `auto-save.focus-lost`. `auto_save_mode` already defaults to
      # on_focus_change.
      enable_auto_save = true;
    }
    // lib.optionalAttrs themed {theme = "ember";};

  # ---- the theme ------------------------------------------------------------
  # Flow finds a user theme by file stem under themes/, and a user theme shadows
  # the built-in of the same name — so the stem IS what `theme` refers to.
  c = config.lib.stylix.colors;
  mk = slot: {color = c.withHashtag.${slot};};
  rgb = slot: map lib.toInt [c."${slot}-rgb-r" c."${slot}-rgb-g" c."${slot}-rgb-b"];

  ground = mk "base00";
  lifted = mk "base01";
  subtle = mk "base02";
  faded = mk "base03";
  dim = mk "base04";
  default = mk "base05";
  critical = mk "base08";
  popout = mk "base0A";
  # Both base0B, as in ./helix-theme.nix: a string in a buffer and a `+` in a
  # diff are two roles that happen to agree on a value.
  literal = mk "base0B";
  added = mk "base0B";
  salient = mk "base0D";

  # The base16 shell mapping, in flow's order. bright black is base03 and bright
  # white base07; the six hues repeat, because this palette has one value per hue.
  ansiSlots = [
    "base00"
    "base08"
    "base0B"
    "base0A"
    "base0D"
    "base0E"
    "base0C"
    "base05"
    "base03"
    "base08"
    "base0B"
    "base0A"
    "base0D"
    "base0E"
    "base0C"
    "base07"
  ];
  ansiNames = [
    "ansi_black"
    "ansi_red"
    "ansi_green"
    "ansi_yellow"
    "ansi_blue"
    "ansi_magenta"
    "ansi_cyan"
    "ansi_white"
    "ansi_bright_black"
    "ansi_bright_red"
    "ansi_bright_green"
    "ansi_bright_yellow"
    "ansi_bright_blue"
    "ansi_bright_magenta"
    "ansi_bright_cyan"
    "ansi_bright_white"
  ];

  tok = scope: style: {inherit scope style;};

  theme =
    {
      name = "ember";
      description = "Ember 3400K Dark, NANO faces (see desktop/helix-theme.nix)";
      type = "dark";

      editor = {
        fg = default;
        bg = ground;
      };

      # helix gets the same shape from `modifiers = ["reversed"]`; flow's
      # FontStyle has no reverse, so the inversion is written out. The cursor is
      # the terminal's steady block (docs/ember-visual-language.md, "A terminal")
      # and inverting the cell is how you draw that without spending a hue.
      editor_cursor = {
        fg = ground;
        bg = default;
      };
      editor_cursor_primary = {
        fg = ground;
        bg = default;
      };
      editor_cursor_secondary = {
        fg = ground;
        bg = dim;
      };

      # `highlight_current_line` is off above; this only matters if it goes back on.
      editor_line_highlight.bg = lifted;

      editor_error.fg = critical;
      editor_warning.fg = popout;
      editor_information.fg = salient;
      editor_hint.fg = faded;
      editor_match = {
        fg = popout;
        fs = "bold";
      };
      editor_selection.bg = subtle;
      editor_whitespace.fg = subtle;

      # No bg on the gutter — it falls through to the editor ground, which is the
      # point. The three diff hues stay: in a one-column gutter the sign's entire
      # meaning IS its colour, and there is no shape to fall back on.
      editor_gutter.fg = faded;
      editor_gutter_active = {
        fg = default;
        fs = "bold";
      };
      editor_gutter_modified.fg = salient;
      editor_gutter_added.fg = added;
      editor_gutter_deleted.fg = critical;

      # A floating surface needs a boundary and this palette's dark end is too
      # compressed for a fill to give one, so widgets get an outline in `faded`
      # over `lifted` — the same answer the bar and helix's popups give.
      editor_widget = {
        fg = default;
        bg = lifted;
      };
      editor_widget_border.fg = faded;

      statusbar = {
        fg = dim;
        bg = ground;
      };
      statusbar_hover = {
        fg = default;
        bg = lifted;
      };

      # The scrollbar is drawn with block characters, so the thumb is the fg and
      # the trough is the bg.
      scrollbar = {
        fg = subtle;
        bg = ground;
      };
      scrollbar_hover = {
        fg = faded;
        bg = ground;
      };
      scrollbar_active = {
        fg = dim;
        bg = ground;
      };

      sidebar = {
        fg = default;
        bg = ground;
      };
      panel = {
        fg = default;
        bg = lifted;
      };

      input = {
        fg = default;
        bg = ground;
      };
      input_border.fg = faded;
      input_placeholder.fg = faded;
      input_option_active.fg = popout;
      input_option_hover = {
        fg = default;
        bg = lifted;
      };

      # Open buffers as a row of names, the current one marked by weight rather
      # than by a tab-shaped fill — helix's bufferline treatment.
      tab_active = {
        fg = default;
        fs = "bold";
      };
      tab_inactive.fg = faded;
      tab_selected = {
        fg = default;
        fs = "bold";
      };
      tab_unfocused_active.fg = dim;
      tab_unfocused_inactive.fg = faded;

      ansi_palette = map rgb ansiSlots;

      # Match the document's own capture names (`keyword.function`, `markup.raw`)
      # rather than routing them through flow's tree-sitter→TextMate fallback
      # table. Matching is longest-dotted-prefix, and an unmatched scope falls
      # through to `editor` — i.e. `default`, which does most of the work here,
      # so `operator`, `punctuation` and every language-specific capture are
      # absent on purpose.
      scope_type = "tree_sitter";
      tokens = [
        # faded — prose, and nothing else. Italic is a real face; JuliaMono ships
        # one, so nothing is synthesised.
        (tok "comment" {
          fg = faded;
          fs = "italic";
        })

        # literal — values written out in the source. A string and a number are
        # the same kind of thing, so they share a face.
        (tok "string" {fg = literal;})
        (tok "character" {fg = literal;})
        (tok "number" {fg = literal;})
        (tok "boolean" {fg = literal;})
        (tok "constant" {fg = literal;})

        # strong — a definition, or the thing being pointed at. `function` also
        # covers .builtin/.call/.macro/.method by prefix.
        (tok "function" {
          fg = default;
          fs = "bold";
        })
        (tok "method" {
          fg = default;
          fs = "bold";
        })
        (tok "constructor" {
          fg = default;
          fs = "bold";
        })
        (tok "label" {
          fg = default;
          fs = "bold";
        })

        # salient — the language, as opposed to anything you named or wrote out.
        (tok "keyword" {fg = salient;})
        (tok "type" {fg = salient;})
        (tok "attribute" {fg = salient;})
        (tok "namespace" {fg = salient;})
        (tok "module" {fg = salient;})
        (tok "tag" {fg = salient;})
        (tok "special" {fg = salient;})
        (tok "variable.builtin" {fg = salient;})

        # markup. Heading level is already carried by the marker and the indent,
        # so all six share one face, and bold/italic carry no colour at all.
        (tok "markup.heading" {
          fg = default;
          fs = "bold";
        })
        (tok "markup.strong" {fs = "bold";})
        (tok "markup.bold" {fs = "bold";})
        (tok "markup.italic" {fs = "italic";})
        (tok "markup.list" {fg = default;})
        (tok "markup.raw" {fg = literal;})
        (tok "markup.quote" {
          fg = faded;
          fs = "italic";
        })
        (tok "markup.link" {fg = salient;})
        (tok "markup.link.url" {
          fg = salient;
          fs = "underline";
        })

        # diff, and the query's own error capture.
        (tok "diff.plus" {fg = added;})
        (tok "diff.minus" {fg = critical;})
        (tok "error" {fg = critical;})
      ];
    }
    // lib.listToAttrs (lib.zipListsWith lib.nameValuePair ansiNames (map mk ansiSlots));
in {
  xdg.configFile =
    {
      "flow/generated.json".text = builtins.toJSON settings;
    }
    // lib.optionalAttrs themed {
      "flow/themes/ember.json".text = builtins.toJSON theme;
    };

  # Seed the include into flow's own file. Appending is enough even when flow has
  # already written a full config: the parser assigns as it reads, so the last
  # `include_files` line wins, and flow keeps the value when it rewrites. Guarded
  # on the path so this runs once rather than growing the file every generation.
  home.activation.flowIncludeGenerated = lib.hm.dag.entryAfter ["writeBoundary"] ''
    flow_config="${config.xdg.configHome}/flow/config"
    if ! grep -qF '${includeFile}' "$flow_config" 2>/dev/null; then
      run mkdir -p "$(dirname "$flow_config")"
      echo 'include_files "${includeFile}"' >>"$flow_config"
    fi
  '';
}
