{ lib, ... }: {
  programs.zed-editor = {
    enable = true;

    # Themes and language support that used to be installed by hand from the
    # extension gallery. `extensions` becomes `auto_install_extensions` in
    # settings.json — Zed still does the downloading, we just declare the list.
    # `nvim-nightfox` provides the dark theme, `min-theme` the light one.
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
    # Corollary: never declare a list-valued key Zed manages itself — jq's `*`
    # replaces arrays wholesale rather than merging them, so declaring
    # `ssh_connections` here would truncate it back to this file on every
    # `nh home switch`. It is deliberately absent.
    userSettings = {
      # Appearance.
      #
      # `theme`, `buffer_font_family`, `buffer_font_size` and `ui_font_size` are
      # all set by stylix's zed target (modules/zed/hm.nix in the stylix input),
      # which renders the base16 scheme through the tinted-zed template into
      # ~/.config/zed/themes/stylix.json and selects it as "Base16 <scheme>".
      # That is the whole point of nixifying this — the editor now tracks
      # ember-3400k-dark along with the terminals, GTK, Qt and noctalia — so
      # they are deliberately absent here rather than fought with mkForce.
      #
      # Fonts are the exception. stylix derives them from `fonts.sansSerif`
      # (DejaVu Sans) and `fonts.sizes.{applications,terminal} * 4/3`, which
      # lands on 16pt UI / 21.3pt buffer — but Zed's UI is read as densely as
      # its buffer, so it keeps the monospace face, and the sizes below are
      # hand-tuned for this panel. `sizes.applications` is a GTK-app default
      # and has no business sizing an editor chrome. mkForce because stylix
      # defines all of these at normal priority, not mkDefault.
      ui_font_family = lib.mkForce "Maple Mono";
      ui_font_size = lib.mkForce 22;
      buffer_font_size = lib.mkForce 20;
      buffer_font_weight = 400;
      icon_theme = {
        mode = "light";
        light = "Zed (Default)";
        dark = "Zed (Default)";
      };
      buffer_line_height = "comfortable";
      text_rendering_mode = "grayscale";

      # Editor
      vim_mode = true;
      base_keymap = "VSCode";
      relative_line_numbers = "enabled";
      cursor_blink = false;
      soft_wrap = "editor_width";
      always_treat_brackets_as_autoclosed = true;
      autosave = "on_focus_change";
      restore_on_startup = "last_workspace";
      ensure_final_newline_on_save = false;
      format_on_save = "off";
      formatter = "language_server";
      line_indicator_format = "short";
      indent_guides = {
        enabled = true;
        coloring = "indent_aware";
      };
      inlay_hints = {
        enabled = true;
        show_type_hints = true;
        show_parameter_hints = true;
        show_other_hints = false;
      };
      centered_layout = {
        left_padding = 0.15;
        right_padding = 0.15;
      };

      # Chrome
      tabs = {
        file_icons = true;
        git_status = true;
      };
      tab_bar = {
        show = true;
        show_nav_history_buttons = false;
      };
      toolbar = {
        breadcrumbs = true;
        quick_actions = false;
        selections_menu = false;
      };
      title_bar.show_sign_in = false;
      project_panel = {
        dock = "left";
        indent_size = 20;
        auto_fold_dirs = true;
        button = true;
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
      git_panel.dock = "left";
      scrollbar = {
        git_diff = false;
        search_results = false;
        selected_symbol = false;
        diagnostics = "none";
      };
      terminal = {
        copy_on_select = true;
        button = true;
        line_height = "comfortable";
        toolbar.breadcrumbs = false;
      };

      # Zed's own dialogs, not the portal ones — the GTK portal picker under
      # niri is worse than what Zed draws itself.
      use_system_path_prompts = false;
      use_system_prompts = false;
      cli_default_open_behavior = "existing_window";

      diagnostics = {
        include_warnings = false;
        inline = {
          enabled = true;
          update_debounce_ms = 150;
          padding = 4;
          min_column = 0;
          max_severity = "error";
        };
      };

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

    userKeymaps = [
      {
        context = "Workspace";
        bindings."ctrl-/" = "agent::Toggle";
      }
      {
        context = "Editor && !VimWaiting && !menu";
        bindings = {
          "ctrl-w" = "pane::CloseActiveItem";
          "ctrl-p" = "file_finder::Toggle";
          "ctrl-j" = "workspace::ToggleBottomDock";
          "ctrl-b" = "workspace::ToggleLeftDock";
        };
      }
    ];
  };
}
