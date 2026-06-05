{ pkgs, ... }:

{
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
        bufferline = "always";
        cursorline = true;
        color-modes = true;
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
          layout = [ "diagnostics" "spacer" "line-numbers" "spacer" "diff" ];
        };

        inline-diagnostics = {
          cursor-line = "warning";
        };

        statusline = {
          left = [ "mode" "spinner" "version-control" ];
          center = [ "file-name" ];
          right = [ "diagnostics" "selections" "position" "file-encoding" "file-line-ending" "file-type" ];
          separator = "│";
          mode.normal = "NORMAL";
          mode.insert = "INSERT";
          mode.select = "SELECT";
        };
      };
    };

    languages =
      let
        tsServers = [ "typescript-language-server" "vscode-eslint-language-server" ];
        # typescript / tsx / javascript / jsx all share the same servers + auto-format.
        tsLangs = map
          (name: {
            inherit name;
            auto-format = true;
            language-servers = tsServers;
          }) [ "typescript" "tsx" "javascript" "jsx" ];
      in
      {
        language-server.rust-analyzer = {
          command = "rust-analyzer";
          config = {
            check.command = "clippy";
            cargo.features = "all";
          };
        };

        language-server.typescript-language-server = {
          command = "typescript-language-server";
          args = [ "--stdio" ];
        };

        language-server.phpactor = {
          command = "phpactor";
          args = [ "language-server" ];
        };

        language-server.vuels = {
          command = "vue-language-server";
          args = [ "--stdio" ];
          config.typescript.tsdk = "${pkgs.typescript}/lib/node_modules/typescript/lib";
        };

        language-server.vscode-eslint-language-server = {
          command = "vscode-eslint-language-server";
          args = [ "--stdio" ];
        };

        language-server.nil = {
          command = "nil";
          config.nil.formatting.command = [ "alejandra" "--quiet" "-" ];
          # Auto-fetch missing flake inputs instead of prompting on every open.
          config.nil.nix.flake.autoArchive = true;
        };

        language-server.marksman = {
          command = "marksman";
          args = [ "server" ];
        };

        language-server.tinymist = {
          command = "tinymist";
        };

        language-server.jdtls = {
          command = "jdtls";
        };

        language-server.harper-ls = {
          command = "harper-ls";
          args = [ "--stdio" ];
        };

        language-server.taplo = {
          command = "taplo";
          args = [ "lsp" "stdio" ];
        };

        language-server.yaml-language-server = {
          command = "yaml-language-server";
          args = [ "--stdio" ];
        };

        language = [
          {
            name = "rust";
            language-servers = [ "rust-analyzer" ];
          }
        ] ++ tsLangs ++ [
          {
            name = "php";
            language-servers = [ "phpactor" ];
          }
          {
            name = "vue";
            language-servers = [ "vuels" ];
          }
          {
            name = "nix";
            auto-format = true;
            language-servers = [ "nil" ];
            formatter = { command = "alejandra"; args = [ "--quiet" "-" ]; };
          }
          {
            name = "markdown";
            language-servers = [ "marksman" "harper-ls" ];
          }
          {
            name = "typst";
            language-servers = [ "tinymist" "harper-ls" ];
          }
          {
            name = "toml";
            auto-format = true;
            language-servers = [ "taplo" ];
            formatter = { command = "taplo"; args = [ "fmt" "-" ]; };
          }
          {
            name = "yaml";
            language-servers = [ "yaml-language-server" ];
          }
          {
            name = "java";
            language-servers = [ "jdtls" ];
          }
          {
            name = "org";
            scope = "source.org";
            file-types = [ "org" ];
            roots = [ ];
            comment-token = "#";
            indent = { tab-width = 2; unit = "  "; };
            grammar = "org";
          }
        ];

        grammar = [{
          name = "org";
          source = {
            git = "https://github.com/milisims/tree-sitter-org";
            rev = "698bb1a34331e68f83fc24bdd1b6f97016bb30de";
          };
        }];
      };
  };
}
