{ pkgs
, lib
, config
, ...
}:
let
  # The vault Obsidian opens (registered in ~/.config/obsidian/obsidian.json,
  # which stays runtime state — it records window geometry and last-opened).
  vault = "Vault.new";

  json = (pkgs.formats.json { }).generate;

  inherit (config.lib.stylix.colors.withHashtag)
    base00 base01 base02 base03 base04 base05 base07
    base08 base09 base0A base0B base0C base0D base0E base0F;

  # Obsidian's built-in theme derives every surface from a 00→100 greyscale ramp
  # plus eight named hues, so recolouring those variables is enough to theme the
  # whole app — no community theme, no per-selector overrides. Dark only: the
  # rice is dark-only (stylix `theme: "obsidian"` below is Obsidian's name for
  # dark mode), so `.theme-light` is deliberately left alone.
  stylixSnippet = pkgs.writeText "stylix.css" ''
    /* Generated from the stylix base16 scheme — see rices/ember/stylix.nix. */
    .theme-dark {
      --color-base-00: ${base00};
      --color-base-05: ${base00};
      --color-base-10: ${base01};
      --color-base-20: ${base01};
      --color-base-25: ${base02};
      --color-base-30: ${base02};
      --color-base-35: ${base03};
      --color-base-40: ${base03};
      --color-base-50: ${base04};
      --color-base-60: ${base04};
      --color-base-70: ${base05};
      --color-base-100: ${base07};

      --color-red: ${base08};
      --color-orange: ${base09};
      --color-yellow: ${base0A};
      --color-green: ${base0B};
      --color-cyan: ${base0C};
      --color-blue: ${base0D};
      --color-purple: ${base0E};
      --color-pink: ${base0F};
    }
  '';
in
{
  home.packages = [ pkgs.obsidian ];

  # Obsidian keeps config *inside* the vault, so these land in a git repo that
  # obsidian-git pushes to mobile. Everything declared here is listed in
  # <vault>/.gitignore and untracked (`git rm --cached`) — otherwise the sync
  # would carry /nix/store symlinks to a phone that has no /nix.
  #
  # Deliberately NOT managed, because Obsidian rewrites them at runtime and a
  # read-only symlink would either break the feature or be clobbered on the next
  # activation: workspace.json / workspace-mobile.json (pane layout),
  # community-plugins.json (written on every plugin install/enable),
  # core-plugins-migration.json, graph.json (tuned by dragging sliders), and
  # plugins/*/data.json (per-plugin state).
  home.file = {
    "${vault}/.obsidian/snippets/stylix.css".source = stylixSnippet;

    "${vault}/.obsidian/appearance.json".source = json "appearance.json" {
      theme = "obsidian"; # Obsidian's name for dark mode
      # No community theme: the built-in one is what stylixSnippet recolours.
      # A theme like Things sets its own --color-base-* and would win.
      cssTheme = "";
      enabledCssSnippets = [ "stylix" ];
      accentColor = base0E;

      interfaceFontFamily = config.stylix.fonts.sansSerif.name;
      textFontFamily = config.stylix.fonts.serif.name;
      monospaceFontFamily = config.stylix.fonts.monospace.name;
      # Machine policy, not a rice fact — a readable size is a function of the
      # panel. Same reasoning as stylix.fonts.sizes.terminal (homes/tempest).
      baseFontSize = 22;
      baseFontSizeAction = false;
    };

    "${vault}/.obsidian/app.json".source = json "app.json" {
      vimMode = true;
      trashOption = "local";
      alwaysUpdateLinks = true;
      promptDelete = false;
      showInlineTitle = true;
      useTab = false;
      readableLineLength = true;
      strictLineBreaks = true;
      spellcheck = true;
      pdfExportSettings = {
        includeName = true;
        pageSize = "Letter";
        landscape = false;
        margin = "2";
        downscalePercent = 100;
      };
    };

    "${vault}/.obsidian/backlink.json".source = json "backlink.json" {
      backlinkInDocument = true;
    };

    "${vault}/.obsidian/hotkeys.json".source = json "hotkeys.json" {
      "command-palette:open" = [{ modifiers = [ "Mod" "Shift" ]; key = "P"; }];
      "switcher:open" = [{ modifiers = [ "Mod" ]; key = "O"; }];
    };

    # Which *core* plugins are on. Community plugins stay runtime-managed (see
    # above) — they are downloaded into the vault, not built by Nix.
    "${vault}/.obsidian/core-plugins.json".source = json "core-plugins.json" {
      audio-recorder = false;
      backlink = true;
      bases = true;
      bookmarks = true;
      canvas = true;
      command-palette = true;
      daily-notes = true;
      editor-status = true;
      file-explorer = true;
      file-recovery = true;
      footnotes = false;
      global-search = true;
      graph = true;
      markdown-importer = true;
      note-composer = true;
      outgoing-link = true;
      outline = true;
      page-preview = true;
      properties = true;
      publish = false;
      random-note = false;
      slash-command = false;
      slides = true;
      switcher = true;
      sync = false;
      tag-pane = true;
      templates = true;
      webviewer = false;
      word-count = true;
      workspaces = false;
      zk-prefixer = false;
    };
  };
}
