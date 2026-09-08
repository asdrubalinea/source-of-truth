{pkgs, ...}: {
  # The theme is its own file — it is the one part of this config that is a
  # claim about *colour* rather than about behaviour, and it is generated from
  # whichever base16 palette the machine has rather than written down here.
  imports = [./helix-theme.nix];

  # Steel scheme config + cogs. These are code, so they're pointed at rather
  # than derived from Nix. recentf.scm is a local fork of mattwparas/helix-
  # config's recentf (see its header for what was changed and why); scratch.scm
  # reuses the same XDG-state + per-repo keying pattern for a scratch buffer,
  # and both share the path/subprocess helpers in cogs/store.scm. User-facing
  # commands (:recent-files, :scratch, …) are registered in helix/helix.scm.
  #
  # cogs/ is symlinked as a whole directory, not file-by-file: Steel resolves a
  # cog's relative `(require "sibling.scm")` next to that cog's *real* path
  # (it canonicalizes the symlink first), so the cogs must land in one store dir
  # together. Per-file symlinks scatter them across separate store paths and the
  # sibling require fails to resolve.
  xdg.configFile = {
    "helix/helix.scm".source = ./helix/helix.scm;
    "helix/init.scm".source = ./helix/init.scm;
    "helix/cogs".source = ./helix/cogs;
  };

  programs.helix = {
    enable = true;

    settings = {
      # space f (recent-files) is bound in init.scm via the Steel `keymap` macro,
      # not here: only that path copies the command's ;;@doc into the keymap
      # infobox. A binding declared in this TOML would render as "Undocumented
      # plugin command" because Helix can't resolve a plugin command's doc.
      #
      # space C copies the current file's absolute path to the clipboard. Safe to
      # bind in TOML (unlike a plugin command): :sh is a built-in, so its doc
      # resolves normally. %{file_path_absolute} is expanded by Helix before the
      # shell runs; the quotes guard paths containing spaces.
      keys.normal.space.C = '':sh wl-copy "%{file_path_absolute}"'';

      editor = {
        line-number = "relative";

        # "multiple", not "always". With one file open the bufferline repeats
        # what the statusline's file-name already says, and a permanent strip of
        # chrome that answers nothing is exactly what principle 3
        # (docs/ember-visual-language.md) refuses to light. Same shape as
        # wezterm's hide_tab_bar_if_only_one_tab.
        bufferline = "multiple";

        # Both off, and both purely cosmetic. `cursorline` paints a full-width
        # row at base01 — 6/255 above the ground, under the discrimination floor
        # on this panel — so it lights a row on every keystroke and shows
        # nothing; the block cursor and the bold current line-number already
        # mark the row. `color-modes` floods the statusline with a per-mode hue,
        # which spends colour on a fact the words NORMAL/INSERT/SELECT state
        # outright.
        cursorline = false;
        color-modes = false;

        # The one box that stays. A popup floats over live text and needs a
        # boundary, and on a palette whose dark end is this compressed a fill
        # cannot provide one (see the gutter note in ./helix-theme.nix), so the
        # boundary is an outline — which is also the bar's own treatment, rather
        # than a second idea about edges.
        popup-border = "all";
        indent-heuristic = "hybrid";
        end-of-line-diagnostics = "hint";

        lsp = {
          display-inlay-hints = true;
        };

        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };

        file-picker.hidden = false;

        soft-wrap.enable = true;

        smart-tab.enable = true;

        auto-save.focus-lost = true;

        gutters = {
          layout = ["diagnostics" "spacer" "line-numbers" "spacer" "diff"];
        };

        inline-diagnostics = {
          cursor-line = "warning";
        };

        statusline = {
          left = ["mode" "spinner" "version-control"];
          center = ["file-name"];
          right = ["diagnostics" "position"];
          # A space, not "│". The dropped four — selections, file-encoding,
          # file-line-ending, file-type — are answers to questions asked a few
          # times a year, held on screen permanently and read never; and a rule
          # drawn between two words is a mark that carries nothing, which is the
          # same reason the statusline no longer has a background.
          separator = " ";
          mode.normal = "NORMAL";
          mode.insert = "INSERT";
          mode.select = "SELECT";
        };
      };
    };

    languages = let
      tsServers = ["typescript-language-server" "vscode-eslint-language-server"];
      # typescript / tsx / javascript / jsx all share the same servers + auto-format.
      tsLangs =
        map
        (name: {
          inherit name;
          auto-format = true;
          language-servers = tsServers;
        }) ["typescript" "tsx" "javascript" "jsx"];
    in {
      language-server.rust-analyzer = {
        command = "rust-analyzer";
        config = {
          check.command = "clippy";
          cargo.features = "all";
        };
      };

      language-server.typescript-language-server = {
        command = "typescript-language-server";
        args = ["--stdio"];
      };

      language-server.phpactor = {
        command = "phpactor";
        args = ["language-server"];
      };

      language-server.vuels = {
        command = "vue-language-server";
        args = ["--stdio"];
        config.typescript.tsdk = "${pkgs.typescript}/lib/node_modules/typescript/lib";
      };

      language-server.vscode-eslint-language-server = {
        command = "vscode-eslint-language-server";
        args = ["--stdio"];
      };

      language-server.nil = {
        command = "nil";
        config.nil.formatting.command = ["alejandra" "--quiet" "-"];
        # Auto-fetch missing flake inputs instead of prompting on every open.
        config.nil.nix.flake.autoArchive = true;
      };

      language-server.marksman = {
        command = "marksman";
        args = ["server"];
      };

      language-server.tinymist = {
        command = "tinymist";
      };

      language-server.jdtls = {
        command = "jdtls";
      };

      language-server.harper-ls = {
        command = "harper-ls";
        args = ["--stdio"];
      };

      language-server.taplo = {
        command = "taplo";
        args = ["lsp" "stdio"];
      };

      language-server.yaml-language-server = {
        command = "yaml-language-server";
        args = ["--stdio"];
      };

      language =
        [
          {
            name = "rust";
            language-servers = ["rust-analyzer"];
          }
        ]
        ++ tsLangs
        ++ [
          {
            name = "php";
            language-servers = ["phpactor"];
          }
          {
            name = "vue";
            language-servers = ["vuels"];
          }
          {
            name = "nix";
            auto-format = true;
            language-servers = ["nil"];
            formatter = {
              command = "alejandra";
              args = ["--quiet" "-"];
            };
          }
          {
            name = "markdown";
            language-servers = ["marksman" "harper-ls"];
          }
          {
            name = "typst";
            language-servers = ["tinymist" "harper-ls"];
          }
          {
            name = "toml";
            auto-format = true;
            language-servers = ["taplo"];
            formatter = {
              command = "taplo";
              args = ["fmt" "-"];
            };
          }
          {
            name = "yaml";
            language-servers = ["yaml-language-server"];
          }
          {
            name = "java";
            language-servers = ["jdtls"];
          }
          {
            name = "org";
            scope = "source.org";
            file-types = ["org"];
            roots = [];
            comment-token = "#";
            indent = {
              tab-width = 2;
              unit = "  ";
            };
            grammar = "org";
          }
        ];

      grammar = [
        {
          name = "org";
          source = {
            git = "https://github.com/milisims/tree-sitter-org";
            rev = "698bb1a34331e68f83fc24bdd1b6f97016bb30de";
          };
        }
      ];
    };
  };
}
