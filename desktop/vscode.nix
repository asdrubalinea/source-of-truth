{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode.fhsWithPackages (ps: with ps; [
      rustup
      zlib
      openssl.dev
      pkg-config
    ]);
    profiles.default = {
      userSettings = {
        "editor.fontFamily" = "Maple Mono, monospace";
        "editor.fontSize" = 18;
        "editor.mouseWheelScrollSensitivity" = 3;
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nixd";
        "nix.serverSettings" = {
          nixd = {
            formatting.command = [ "alejandra" ];
          };
        };
        "[nix]" = {
          "editor.defaultFormatter" = "jnoortheen.nix-ide";
          "editor.formatOnSave" = true;
        };
        "[python]" = {
          "editor.defaultFormatter" = "charliermarsh.ruff";
          "editor.formatOnSave" = true;
          "editor.codeActionsOnSave" = {
            "source.fixAll.ruff" = "explicit";
            "source.organizeImports.ruff" = "explicit";
          };
        };
        "python.languageServer" = "Pylance";
        "vim.handleKeys" = {
          "<C-w>" = false;
        };
      };
      extensions = with pkgs.vscode-extensions; [
        dracula-theme.theme-dracula
        vscodevim.vim
        yzhang.markdown-all-in-one
        jnoortheen.nix-ide
        tamasfe.even-better-toml
        ms-python.python
        ms-python.vscode-pylance
        ms-python.debugpy
        charliermarsh.ruff
        bmewburn.vscode-intelephense-client
        xdebug.php-debug
        mkhl.direnv
      ];
      keybindings = [
        {
          key = "ctrl+j";
          command = "workbench.action.terminal.toggleTerminal";
          when = "terminal.active || !terminalFocus";
        }
        {
          key = "ctrl+w";
          command = "workbench.action.closeActiveEditor";
        }
        {
          key = "ctrl+w";
          command = "-workbench.action.terminal.killActiveTab";
          when = "terminalFocus";
        }
      ];
    };
  };
}
