{ pkgs, ... }:

{
  # Steel scheme config + recentf cog (recent-files picker on `space f`).
  # These are code, so they're pointed at rather than derived from Nix. The cog
  # is a local fork of mattwparas/helix-config's recentf.scm (see the header in
  # that file for what was changed and why).
  xdg.configFile = {
    "helix/helix.scm".source = ./helix/helix.scm;
    "helix/init.scm".source = ./helix/init.scm;
    "helix/cogs/recentf.scm".source = ./helix/cogs/recentf.scm;
  };

  programs.helix = {
    enable = true;

    settings = {
      # space f: recent files first, then all other workspace files (one picker).
      keys.normal.space.f = ":recent-files";

      editor = {
        line-number = "relative";
        bufferline = "always";
        cursorline = true;

        lsp = {
          display-inlay-hints = true;
        };

        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };

        file-picker = {
          hidden = false;
        };

        soft-wrap = {
          enable = true;
        };

        statusline = {
          left = [ "mode" "spinner" ];
          center = [ "file-name" ];
          right = [ "diagnostics" "selections" "position" "file-encoding" "file-line-ending" "file-type" ];
          separator = "│";
          mode.normal = "NORMAL";
          mode.insert = "INSERT";
          mode.select = "SELECT";
        };
      };
    };

    languages = {
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

      language = [
        {
          name = "rust";
          language-servers = [ "rust-analyzer" ];
        }
        {
          name = "typescript";
          auto-format = true;
          language-servers = [ "typescript-language-server" "vscode-eslint-language-server" ];
        }
        {
          name = "tsx";
          auto-format = true;
          language-servers = [ "typescript-language-server" "vscode-eslint-language-server" ];
        }
        {
          name = "javascript";
          auto-format = true;
          language-servers = [ "typescript-language-server" "vscode-eslint-language-server" ];
        }
        {
          name = "jsx";
          auto-format = true;
          language-servers = [ "typescript-language-server" "vscode-eslint-language-server" ];
        }
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
          language-servers = [ "marksman" ];
        }
        {
          name = "typst";
          language-servers = [ "tinymist" ];
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
