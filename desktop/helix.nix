{ ... }:

{
  programs.helix = {
    enable = true;

    settings = {
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

      language = [
        {
          name = "rust";
          language-servers = [ "rust-analyzer" ];
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
