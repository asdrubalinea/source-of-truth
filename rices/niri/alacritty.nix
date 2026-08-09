{ pkgs, lib, config, ... }:
let
  # `path:line[:col]` → open in helix. Ports the hyperlink rule that lived in
  # the old rices/niri/wezterm.nix.
  #
  # Alacritty runs a hint command detached, with no terminal of its own, so
  # unlike wezterm's SpawnCommandInNewTab this has to bring its own window: the
  # wrapper execs a fresh alacritty running hx. It also refuses to spawn for a
  # path that isn't on disk, which is what keeps a stray Ctrl+click on build
  # output from opening an empty buffer.
  #
  # Relative hits (cargo, rg, git) are best-effort here: alacritty hands the
  # hint text to the command with no notion of the shell's cwd, so they resolve
  # only when they happen to be relative to alacritty's own working directory.
  # Absolute and ~/ paths always work. wezterm could do better because it knew
  # the pane's cwd; alacritty exposes no equivalent hook.
  hxOpen = pkgs.writeShellScript "alacritty-hx-open" ''
    target="$1"
    path="''${target%%:*}"
    position="''${target#*:}"
    case "$path" in
      '~'/*) path="$HOME/''${path#'~'/}" ;;
    esac
    [ -f "$path" ] || exit 0
    exec ${config.programs.alacritty.package}/bin/alacritty \
      -e ${config.programs.helix.package}/bin/hx "$path:$position"
  '';
in
lib.mkIf config.rices.niri.enable {
  # Colors and fonts come from stylix's alacritty target (see stylix.nix). This
  # module only sets structural/behavioural options.
  #
  # Note there is no font *fallback* list here, because alacritty has no such
  # config: it takes one family and leaves everything else to fontconfig. Nerd
  # Font glyphs (prompt segments, helix gutter icons) therefore come from
  # fontconfig picking up nerd-fonts.symbols-only from desktop/fonts.nix, not
  # from an explicit wedge the way wezterm's font_with_fallback did it.
  programs.alacritty = {
    enable = true;
    settings = {
      # TERM=alacritty, not xterm-256color: alacritty's own terminfo (shipped in
      # the package, and installed on hydra/orchid for ssh) is the only entry
      # that advertises Smulx — styled/curly underlines for helix diagnostics —
      # and Sync, the DECSET 2026 synchronized-output capability. Sync is what
      # lets tmux and TUIs batch a repaint into one atomic frame instead of
      # letting a half-drawn screen reach the compositor, so it is load-bearing
      # for the redraw flicker this rice switched terminals to escape. See
      # desktop/tmux.nix, which forwards both capabilities inward.
      #
      # The xterm-256color fallback for remote hosts is handled once, by the
      # ssh `SetEnv TERM` in homes/tempest/default.nix.
      env.TERM = "alacritty";

      window = {
        padding = {
          x = 4;
          y = 4;
        };
        decorations = "None";
        dimensions = {
          columns = 160;
          lines = 48;
        };
        dynamic_title = true;
      };

      scrolling = {
        history = 100000;
        multiplier = 10;
      };

      cursor = {
        style = {
          shape = "Beam";
          blinking = "Off";
        };
        thickness = 0.15;
        unfocused_hollow = true;
      };

      # Left-click selection lands in BOTH clipboards, matching the wezterm
      # mouse binding this replaces (CompleteSelection
      # "ClipboardAndPrimarySelection"). Alacritty already fills the primary
      # selection; this adds the regular clipboard.
      selection.save_to_clipboard = true;

      # Bell: sound only, no flash. duration = 0 disables the visual bell
      # animation outright — a full-window flash on every BEL (backspace on an
      # empty prompt, arrow-up at a bash history edge over ssh) fires constantly
      # and is exactly the kind of blinking this rice is trying to be rid of.
      # SystemBeep doesn't work on Wayland, hence paplay-by-way-of-canberra.
      bell = {
        duration = 0;
        command = {
          program = "${pkgs.libcanberra-gtk3}/bin/canberra-gtk-play";
          args = [ "-i" "bell" ];
        };
      };

      keyboard.bindings = [
        # Ctrl+Backspace and Super+Backspace → delete the word left of cursor.
        #
        # ESC+Ctrl+H (0x1b 0x08) is the traditional sequence that
        # prompt_toolkit's emacs bindings already map to backward_kill_word.
        # The modern kitty-protocol CSI u form gets echoed literally as
        # "[127;5u" by prompt_toolkit 3.0.52 (Hermes's TUI input library),
        # which doesn't parse CSI u.
        #
        # These \uXXXX escapes are written literally on purpose: pkgs.formats
        # .toml would emit them as "\\u001b", so home-manager's alacritty module
        # stashes each one behind a placeholder and restores a real TOML escape
        # at generation time.
        {
          key = "Backspace";
          mods = "Control";
          chars = "\\u001b\\u0008";
        }
        {
          key = "Backspace";
          mods = "Super";
          chars = "\\u001b\\u0008";
        }
      ];

      # Declaring hints.enabled REPLACES alacritty's default array, so the stock
      # URL opener has to be restated here alongside the helix rule — the same
      # trap as wezterm's default_hyperlink_rules().
      #
      # Both rules activate on Ctrl+click, not plain click: a bare left-click
      # would otherwise open an editor on every stray click landing on a path in
      # build output.
      hints.enabled = [
        {
          regex = ''(ipfs:|ipns:|magnet:|mailto:|gemini://|gopher://|https://|http://|news:|file:|git://|ssh:|ftp://)[^\s<>"'`{}\^⟨⟩]+'';
          # Also surface OSC 8 hyperlinks, which fish and helix both emit.
          hyperlinks = true;
          post_processing = true;
          persist = false;
          # Bare name, resolved off the session PATH alacritty inherits from
          # niri — matching alacritty's own default, and letting the handler
          # lookup in desktop/mimeapps.nix apply.
          command = "xdg-open";
          mouse = {
            enabled = true;
            mods = "Control";
          };
          binding = {
            key = "O";
            mods = "Control|Shift";
          };
        }
        {
          # `path:line[:col]` — the shape nix, cargo, rg and helix all print
          # errors in. Alacritty matches on the whole regex (no capture groups
          # to select from, no lookbehind), so wezterm's leading
          # (?:^|[\s"'(\[]) anchor is gone; post_processing trims trailing
          # punctuation instead. Ordering matters: the URL rule above runs
          # first, so a `.../a.py:12` inside a link stays a link.
          regex = ''(?:[~.]?/)?[\w./+-]+\.[a-zA-Z][\w]{0,9}:\d+(?::\d+)?'';
          post_processing = true;
          persist = false;
          command = "${hxOpen}";
          mouse = {
            enabled = true;
            mods = "Control";
          };
        }
      ];
    };
  };
}
