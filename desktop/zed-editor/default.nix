{
  lib,
  config,
  ...
}: let
  # Ember at reading intensity (CONTEXT.md: "glance palette / read palette").
  #
  # stylix's zed target renders ember-3400k-dark through the tinted-zed template
  # into ~/.config/zed/themes/stylix.json, which maps all eight accents across 43
  # syntax tokens at full strength. That is the right register for a bar readout
  # and the wrong one for a surface read for eight hours — and the mapping is
  # mechanical, so it lands base08 (the error/deletion red) on `property`, `tag`
  # and `label`, and base09 (the ember, also the focused window border) on every
  # number and boolean. Ordinary code then renders in the two colours the rest of
  # the desktop uses to mean "broken" and "focused".
  #
  # So: three accents keep a colour, everything else flattens to the foreground.
  # Derived from the scheme rather than restated as hexes, so a palette change
  # still reaches the buffer.
  c = config.lib.stylix.colors.withHashtag;

  paint = color: tokens: lib.genAttrs tokens (_: {inherit color;});

  # Neutralised. Listed exhaustively and not derived, because
  # `experimental.theme_overrides` merges over only the keys it is given — an
  # unnamed token silently keeps the template's value. Kept against the 43 in
  # themes/stylix.json; a template that grows a token needs it added here.
  neutral = [
    "attribute"
    "embedded"
    "label"
    "link_uri"
    "namespace"
    "number"
    "operator"
    "preproc"
    "primary"
    "property"
    "punctuation"
    "punctuation.bracket"
    "punctuation.delimiter"
    "punctuation.list_marker"
    "punctuation.markup"
    "punctuation.special"
    "selector"
    "selector.pseudo"
    "tag"
    "variable"
    "variable.special"
  ];
in {
  programs.zed-editor = {
    enable = true;

    # Themes and language support that used to be installed by hand from the
    # extension gallery. `extensions` becomes `auto_install_extensions` in
    # settings.json — Zed still does the downloading, we just declare the list.
    extensions = [
      "catppuccin"
      "graphql"
      "haskell"
      "html"
      "log"
      "min-theme"
      "nix"
      "nvim-nightfox"
      "php"
      "toml"
      "typst"
      "vue"
    ];

    # `mutableUserSettings`/`mutableUserKeymaps` default to true, which is what
    # we want: activation deep-merges the attrs below *over* whatever is on
    # disk instead of replacing the file. Zed writes its own state into
    # settings.json (ssh_connections and their recent project lists, agent
    # favourites, theme picked from the UI), and that survives.
    #
    # Keymaps are the exception, and are declared immutable below. Their merge
    # is `$dynamic + $static | group_by(.context)`, which is ADDITIVE: deleting a
    # binding here never deletes it from disk, so a retired binding lingers in
    # keymap.json forever and shadows its replacement. Unlike settings.json,
    # keymap.json holds nothing Zed generates, so there is nothing to preserve.
    #
    # Corollary: never declare a list-valued key Zed manages itself — jq's `*`
    # replaces arrays wholesale rather than merging them, so declaring
    # `ssh_connections` here would truncate it back to this file on every
    # `nh home switch`. It is deliberately absent.
    #
    # Second corollary, for anyone changing settings from inside Zed: a value
    # this file declares is restored at the next switch, silently. The runtime
    # toggle actions (editor::ToggleInlayHints, ToggleInlineDiagnostics,
    # ToggleIndentGuides, workspace::ToggleCenteredLayout) are editor state and
    # write nothing, so experiment with those; a change made in the settings UI
    # only looks like it stuck.
    userSettings = {
      # Appearance.
      #
      # `theme`, `buffer_font_family` and `ui_font_family` come from stylix's zed
      # target (modules/zed/hm.nix in the stylix input) — the editor tracks
      # ember-3400k-dark along with the terminals, GTK, Qt and noctalia — so they
      # are deliberately absent here rather than fought with mkForce.
      #
      # Font SIZES are the exception: stylix derives them from
      # `fonts.sizes.{applications,terminal} * 4/3`, and `sizes.applications` is
      # a GTK-app default with no business sizing an editor. mkForce because
      # stylix defines them at normal priority, not mkDefault.
      #
      # The two are equal, which is not Zed's own ratio (16 UI / 15 buffer).
      # That default exists because ui_font_family is `.ZedSans`, a proportional
      # face needing more pixels than a mono to read the same size. ember puts
      # ONE face in both slots (rices/ember/stylix.nix), so the ratio lost its
      # justification and only made the chrome shout over the code.
      ui_font_size = lib.mkForce 20;
      buffer_font_size = lib.mkForce 20;
      buffer_font_weight = 400;
      icon_theme = {
        mode = "light";
        light = "Zed (Default)";
        dark = "Zed (Default)";
      };
      buffer_line_height = "comfortable";
      text_rendering_mode = "grayscale";

      "experimental.theme_overrides".syntax =
        paint c.base05 neutral
        // paint c.base03 ["comment" "comment.doc" "hint"]
        // paint c.base0B [
          "string"
          "string.escape"
          "string.regex"
          "string.special"
          "string.special.symbol"
          "text.literal"
        ]
        # `boolean` and `constant` ride the keyword accent rather than taking one
        # of their own — `true`/`false`/`null` read as keywords anyway.
        // paint c.base09 ["keyword" "boolean" "constant"]
        # What is *called* and what is *declared*. Flattening these was a
        # register error in the other direction: a file of function calls and
        # type names went uniformly cream, which is not a read palette, just an
        # absent one. base0D is also the slot with the most saturation headroom
        # under wlsunset (see ember-3400k-dark.yaml), so it survives the warm
        # filter at the size a buffer is read.
        // paint c.base0D ["function" "constructor"]
        // paint c.base0C ["type" "enum" "variant"]
        // {
          # An override replaces a token's whole entry, so the five that carry
          # weight or slope have to restate it or markdown loses bold and italic.
          emphasis = {
            color = c.base05;
            font_style = "italic";
          };
          "emphasis.strong" = {
            color = c.base05;
            font_weight = 700;
          };
          title = {
            color = c.base05;
            font_weight = 700;
          };
          link_text = {
            color = c.base05;
            font_style = "normal";
          };
          predictive = {
            color = c.base03;
            font_style = "italic";
          };
        };

      # Editor
      vim_mode = true;
      base_keymap = "VSCode";
      relative_line_numbers = "enabled";
      cursor_blink = false;
      always_treat_brackets_as_autoclosed = true;
      autosave = "on_focus_change";
      restore_on_startup = "last_workspace";
      ensure_final_newline_on_save = false;
      format_on_save = "off";
      formatter = "language_server";
      line_indicator_format = "short";

      # A fixed measure. `editor_width` wrapped at whatever the pane happened to
      # be — around 280 columns on the ultrawide and over 200 on the OLED
      # (homes/tempest/monitors.nix), and different on each. `bounded` takes the
      # smaller of this and the pane, so the column is the same everywhere.
      # 100 rather than the conventional 80: Nix attrsets and Vue SFCs nest, and
      # a wrap you did not ask for is its own distraction.
      soft_wrap = "bounded";
      preferred_line_length = 100;

      # Padding for `workspace::ToggleCenteredLayout`, which is bound to ctrl-/
      # below. Centering has no settings-level "on" — it is toggle-only — so
      # `bounded` above is what fixes the measure by default, and this only
      # decides where the column sits once summoned.
      centered_layout = {
        left_padding = 0.15;
        right_padding = 0.15;
      };

      indent_guides = {
        enabled = true;
        # "indent_aware" cycles a different colour per depth — a rainbow down
        # the gutter of every nested file. "fixed" keeps the structural line.
        coloring = "fixed";
      };

      # Both of these are off in Zed by default and were turned on here on
      # purpose; both are now off on purpose. Inlay hints inject pseudo-text
      # *between* real characters, pushing code sideways; inline diagnostics
      # redraw an end-of-line message 150ms after every keystroke that breaks the
      # parse, which with format_on_save off and autosave on focus change is most
      # of the time you are typing. Squiggle underlines are not configurable and
      # remain either way, so the "something is wrong here" marker survives —
      # diagnostics::Deploy gives the list on request. The sub-keys below stay:
      # they describe what comes back when the toggle actions turn these on.
      inlay_hints = {
        enabled = false;
        show_type_hints = true;
        show_parameter_hints = true;
        show_other_hints = false;
      };
      diagnostics = {
        button = false;
        include_warnings = false;
        inline = {
          enabled = false;
          update_debounce_ms = 150;
          padding = 4;
          min_column = 0;
          max_severity = "error";
        };
      };

      # Chrome. The rule is the bar's (CONTEXT.md): nothing on screen by
      # default, everything summonable. ctrl-b and ctrl-j below are the summons
      # for the docks, so the docks do not need buttons advertising them.
      tab_bar = {
        show = true;
        show_nav_history_buttons = false;
        show_tab_bar_buttons = false;
      };
      tabs = {
        file_icons = false;
        git_status = false;
      };
      # The tab bar carries which-file-am-I-in, so the status strip has no job
      # left. Off entirely rather than pruned button by button.
      status_bar."experimental.show" = false;
      toolbar = {
        breadcrumbs = false;
        quick_actions = false;
        selections_menu = false;
      };
      title_bar = {
        show_sign_in = false;
        show_branch_name = false;
        show_branch_status_icon = false;
        show_project_items = false;
        show_onboarding_banner = false;
        show_user_picture = false;
        show_user_menu = false;
      };
      # Line numbers stay (vim motions read them). The rest of the gutter is
      # click targets for a mouse workflow this config does not have.
      gutter = {
        line_numbers = true;
        runnables = false;
        folds = false;
        bookmarks = false;
        breakpoints = false;
        # Was 4, reserving room for "9999" while relative numbers are two
        # digits. It is a minimum, so long files still widen it.
        min_line_number_digits = 3;
      };
      # `show = "never"` supersedes the per-marker flags that used to be here
      # (git_diff, search_results, selected_symbol, diagnostics) — with no
      # scrollbar drawn there is nothing for them to mark.
      scrollbar.show = "never";
      project_panel = {
        dock = "left";
        indent_size = 20;
        auto_fold_dirs = true;
        button = false;
        git_status = true;
      };
      outline_panel = {
        dock = "left";
        button = false;
      };
      collaboration_panel = {
        dock = "left";
        button = false;
      };
      notification_panel.button = false;
      # Right, not left. `button` means "button in the status bar" for every
      # panel, and the status bar is off — so two panels sharing the left dock
      # have no switcher at all and the second one is simply unreachable. One
      # tenant per dock: files left (ctrl-b), git right (ctrl-shift-g). The right
      # dock is free because `disable_ai` retired the agent that used it.
      git_panel = {
        dock = "right";
        button = false;
      };
      terminal = {
        copy_on_select = true;
        button = false;
        line_height = "comfortable";
        toolbar.breadcrumbs = false;
      };

      # Zed's own dialogs, not the portal ones — the GTK portal picker under
      # niri is worse than what Zed draws itself.
      use_system_path_prompts = false;
      use_system_prompts = false;
      cli_default_open_behavior = "existing_window";

      file_scan_exclusions = [
        "**/.git"
        "**/.svn"
        "**/.hg"
        "**/.jj"
        "**/CVS"
        "**/.DS_Store"
        "**/Thumbs.db"
        "**/.classpath"
        "**/.settings"
        "**/result"
        "**/vendor"
        "**/target"
      ];

      lsp = {
        rust-analyzer.initialization_options.check.command = "clippy";
        hls.initialization_options.haskell.formattingProvider = "fourmolu";
      };

      languages.Haskell = {
        prettier.allowed = true;
        show_whitespaces = "selection";
        ensure_final_newline_on_save = true;
        formatter = "language_server";
        format_on_save = "on";
      };

      # Agent work happens in Claude Code, not in the editor. `agent.dock` and
      # `agent_servers` stay on disk (Zed writes favourite models there) but
      # the built-in AI stays off.
      disable_ai = true;
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
    };

    # Immutable: see the additive-merge note above. A binding removed here has
    # to actually disappear, which the deep-merge cannot do.
    mutableUserKeymaps = false;

    userKeymaps = [
      {
        # Workspace context, NOT Editor: these have to fire while a panel holds
        # focus, and an `Editor`-scoped binding does not match there. That is
        # what stranded the docks — `ctrl-b` only existed inside the buffer, so
        # once focus was in the git panel nothing could move it.
        #
        # `ToggleFocus` per panel rather than `ToggleLeftDock`: a dock toggle
        # reopens whichever panel was last active, which is not a switcher.
        # Keys follow base_keymap = "VSCode" — ctrl-b explorer, ctrl-shift-g
        # source control (and ctrl-shift-g avoids shadowing vim's ctrl-g).
        #
        # ctrl-/ used to open the agent panel, which `disable_ai` had already
        # switched off. Centering is the one thing above that has no settings
        # form and must be summoned.
        context = "Workspace";
        bindings = {
          "ctrl-/" = "workspace::ToggleCenteredLayout";
          "ctrl-b" = "project_panel::ToggleFocus";
          "ctrl-shift-g" = "git_panel::ToggleFocus";
        };
      }
      {
        context = "Editor && !VimWaiting && !menu";
        bindings = {
          "ctrl-w" = "pane::CloseActiveItem";
          "ctrl-p" = "file_finder::Toggle";
          "ctrl-j" = "workspace::ToggleBottomDock";
        };
      }
    ];
  };
}
