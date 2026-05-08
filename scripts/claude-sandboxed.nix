{ pkgs, ... }:

let
  claudeSandboxed = pkgs.writeScriptBin "claude-sandboxed" ''
    #!${pkgs.stdenv.shell}
    set -euo pipefail

    PROJECT_DIR="$(${pkgs.coreutils}/bin/realpath "$PWD")"

    if [ "$PROJECT_DIR" = "$HOME" ] || [ "$PROJECT_DIR" = "/" ]; then
      echo "claude-sandboxed: refusing to run with project dir = $PROJECT_DIR" >&2
      echo "cd into a project directory first." >&2
      exit 1
    fi

    SSH_BIND=()
    if [ -n "''${SSH_AUTH_SOCK:-}" ] && [ -S "''${SSH_AUTH_SOCK:-}" ]; then
      SSH_BIND=(--ro-bind-try "$SSH_AUTH_SOCK" "$SSH_AUTH_SOCK")
    fi

    exec ${pkgs.bubblewrap}/bin/bwrap \
      --die-with-parent \
      --unshare-pid --unshare-ipc --unshare-uts \
      --hostname claude-sandbox \
      --proc /proc \
      --dev-bind /dev /dev \
      --tmpfs /tmp \
      --tmpfs /run/user \
      --ro-bind /nix/store /nix/store \
      --ro-bind /etc /etc \
      --ro-bind /run/current-system /run/current-system \
      --ro-bind /run/wrappers /run/wrappers \
      --tmpfs "$HOME" \
      --bind "$HOME/.claude" "$HOME/.claude" \
      --bind-try "$HOME/.cache" "$HOME/.cache" \
      --ro-bind-try "$HOME/.gitconfig" "$HOME/.gitconfig" \
      --ro-bind-try "$HOME/.config/git" "$HOME/.config/git" \
      "''${SSH_BIND[@]}" \
      --bind "$PROJECT_DIR" "$PROJECT_DIR" \
      --chdir "$PROJECT_DIR" \
      --setenv HOME "$HOME" \
      --setenv USER "$USER" \
      --setenv SANDBOXED claude \
      ${pkgs.claude-code}/bin/claude "$@"
  '';
in
{
  home.packages = [ claudeSandboxed ];
}
