{ pkgs, lib, config, ... }:
lib.mkIf config.rices.niri.enable {
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      local wezterm = require 'wezterm'
      local config = wezterm.config_builder()
      local act = wezterm.action

      -- wezterm's own terminfo (shipped in the package and propagated into the
      -- user env) buys undercurl and coloured underlines for helix
      -- diagnostics, plus proper styled-underline reporting. Remote hosts need
      -- the entry too, so hydra and orchid install pkgs.wezterm.terminfo; a
      -- host that lacks it wants TERM=xterm-256color for that ssh session.
      config.term = "wezterm"

      -- Disambiguated key reporting (CSI u), so helix can tell Shift+Enter,
      -- Ctrl+Enter and Ctrl+; apart instead of seeing them collapse onto the
      -- legacy encodings. tmux forwards it via extended-keys — see
      -- desktop/tmux.nix.
      config.enable_kitty_keyboard = true

      -- Nix owns this install, so the built-in update check is pure noise.
      config.check_for_updates = false
      -- 3500 lines is thin for a nix build log in a pane that isn't tmux.
      config.scrollback_lines = 20000
      -- OSC 9/777 notifications from the pane you are already looking at are
      -- redundant; let noctalia surface only the unfocused ones.
      config.notification_handling = "SuppressFromFocusedPane"
      -- niri decides window geometry, so a font-size change must not try to
      -- resize the window to match.
      config.adjust_window_size_when_changing_font_size = false

      -- Bell: play a sound via paplay since SystemBeep doesn't work on Wayland.
      -- No visual flash — a 0-duration visual_bell keeps the whole window from
      -- blinking red on every BEL (backspace-on-empty, arrow-up on a bash
      -- history edge over ssh).
      config.audible_bell = "Disabled"
      config.visual_bell = {
        fade_in_function = "EaseIn",
        fade_in_duration_ms = 0,
        fade_out_function = "EaseOut",
        fade_out_duration_ms = 0,
      }

      wezterm.on("bell", function(window, pane)
        wezterm.background_child_process({
          "${pkgs.libcanberra-gtk3}/bin/canberra-gtk-play", "-i", "bell",
        })
      end)

      -- Font. stylix sets `font` to <monospace, emoji>, which leaves Nerd Font
      -- glyphs (prompt segments, helix gutter icons) to wezterm's implicit
      -- fontconfig fallback and whatever metrics that lands on. Re-declare the
      -- same list with nerd-fonts.symbols-only (installed in ./fonts.nix)
      -- wedged in the middle — extraConfig merges after stylix, so this wins.
      -- Family names come from stylix so the two can't drift apart.
      config.font = wezterm.font_with_fallback {
        "${config.stylix.fonts.monospace.name}",
        "Symbols Nerd Font Mono",
        "${config.stylix.fonts.emoji.name}",
      }

      -- Cursor
      config.default_cursor_style = "SteadyBar"

      -- Tabs.
      --
      -- The retro tab bar draws in the terminal font/grid, which suits
      -- window_decorations = "NONE" (the fancy bar expects a titlebar) and is
      -- the variant stylix colours via colors.tab_bar.
      config.use_fancy_tab_bar = false
      config.hide_tab_bar_if_only_one_tab = true
      config.tab_max_width = 32
      -- Closing a tab lands on the last-used tab, not the right-hand neighbour.
      config.switch_to_last_active_tab_when_closing_tab = true

      -- "3 ~/p/source-of-truth ●" — index, best available title, unseen-output
      -- marker. Returns a plain string so the stylix tab_bar palette keeps
      -- deciding active/inactive colours.
      wezterm.on("format-tab-title", function(tab, tabs, panes, conf, hover, max_width)
        local pane = tab.active_pane
        local title = tab.tab_title
        if title == nil or #title == 0 then
          -- The shell's OSC title (fish reports cwd + command); fall back to
          -- the foreground process basename when nothing set one.
          title = pane.title
          if title == nil or #title == 0 then
            local proc = pane.foreground_process_name or ""
            title = proc:match("([^/]+)$") or "shell"
          end
        end
        local marker = pane.has_unseen_output and " ●" or ""
        local text = " " .. (tab.tab_index + 1) .. " " .. title .. marker .. " "
        return wezterm.truncate_right(text, max_width)
      end)

      -- Tab keys, additive to wezterm's defaults (CTRL+SHIFT+T new,
      -- CTRL+SHIFT+W close, CTRL+TAB / CTRL+PAGEUP/DOWN next/prev,
      -- CTRL+SHIFT+PAGEUP/DOWN reorder).
      --
      -- ALT is the only comfortable modifier left: niri owns every Super
      -- chord, and tmux binds bare CTRL+T/P/N at root level. ALT+Tab and
      -- ALT+<digit> stay clear of fish's ALT+letter bindings too.
      config.keys = {
        -- Toggle back and forth between the two most recently used tabs.
        { key = "Tab", mods = "ALT", action = act.ActivateLastTab },
        -- Jump to any tab by name.
        { key = "e", mods = "CTRL|SHIFT", action = act.ShowLauncherArgs { flags = "FUZZY|TABS" } },

        -- Ctrl+Backspace and Super/Cmd+Backspace → delete the word left of cursor.
        --
        -- WezTerm sends the modern kitty-protocol CSI u sequence (ESC [ 127 ; 5 u)
        -- for these when enable_kitty_keyboard = true, but prompt_toolkit 3.0.52
        -- (Hermes's TUI input library) doesn't parse CSI u — the raw bytes get
        -- echoed literally as "[127;5u". Override with ESC+Ctrl+H (0x1b 0x08),
        -- the traditional sequence that prompt_toolkit's Emacs bindings already
        -- map to backward_kill_word.
        { key = "Backspace", mods = "CTRL", action = act.SendString "\x1b\x08" },
        { key = "Backspace", mods = "SUPER", action = act.SendString "\x1b\x08" },
        -- Name the current tab (pins the title against shell OSC updates).
        {
          key = ",",
          mods = "CTRL|SHIFT",
          action = act.PromptInputLine {
            description = "Tab title:",
            action = wezterm.action_callback(function(window, pane, line)
              if line then
                window:active_tab():set_title(line)
              end
            end),
          },
        },
      }

      -- ALT+1..9 go straight to a tab, ALT+0 to the rightmost one.
      for i = 1, 9 do
        table.insert(config.keys, { key = tostring(i), mods = "ALT", action = act.ActivateTab(i - 1) })
      end
      table.insert(config.keys, { key = "0", mods = "ALT", action = act.ActivateTab(-1) })

      -- Links.
      --
      -- On top of the stock URL rules, make `path:line[:col]` clickable — the
      -- shape nix, cargo, rg and helix all print errors in — and route it into
      -- helix. The leading (?:^|[\s"'(\[]) anchor keeps the rule from firing
      -- inside a URL's own path, and the handler refuses to spawn anything for
      -- a path that is not actually on disk.
      config.hyperlink_rules = wezterm.default_hyperlink_rules()
      table.insert(config.hyperlink_rules, {
        regex = [==[(?:^|[\s"'(\[])((?:[~.]?/)?[\w./+-]+\.[a-zA-Z][\w]{0,9}:\d+(?::\d+)?)]==],
        format = "hx://$1",
        highlight = 1,
      })

      wezterm.on("open-uri", function(window, pane, uri)
        local target = uri:match("^hx://(.+)")
        if not target then
          return true -- not ours, let wezterm open it the usual way
        end

        local path, position = target:match("^(.-):(%d+:?%d*)$")
        if not path then
          return false
        end

        if path:sub(1, 2) == "~/" then
          path = wezterm.home_dir .. path:sub(2)
        elseif path:sub(1, 1) ~= "/" then
          -- Relative hits (cargo, rg, git) resolve against the pane's cwd,
          -- which is a Url object on current builds and a string on old ones.
          local cwd = pane:get_current_working_dir()
          if not cwd then
            return false
          end
          local base
          if type(cwd) == "userdata" then
            base = cwd.file_path
          else
            base = (tostring(cwd):gsub("^file://[^/]*", ""))
          end
          if not base then
            return false
          end
          path = base:gsub("/$", "") .. "/" .. path
        end

        local probe = io.open(path, "r")
        if not probe then
          wezterm.log_info("hx:// no such file, ignoring click: " .. path)
          return false
        end
        probe:close()

        -- helix takes file:row:col directly, so the column survives the trip.
        window:perform_action(
          act.SpawnCommandInNewTab {
            args = { "${config.programs.helix.package}/bin/hx", path .. ":" .. position },
          },
          pane
        )
        return false
      end)

      -- Link activation moves to CTRL+click. The default plain left-click
      -- would otherwise open an editor on every stray click landing on a path
      -- in build output.
      config.mouse_bindings = {
        {
          event = { Up = { streak = 1, button = "Left" } },
          mods = "NONE",
          action = act.CompleteSelection "ClipboardAndPrimarySelection",
        },
        {
          event = { Up = { streak = 1, button = "Left" } },
          mods = "CTRL",
          action = act.OpenLinkAtMouseCursor,
        },
        -- Swallow the matching mouse-down so it isn't also forwarded to a
        -- mouse-reporting app underneath (tmux, helix).
        {
          event = { Down = { streak = 1, button = "Left" } },
          mods = "CTRL",
          action = act.Nop,
        },
      }

      -- Window
      config.window_padding = {
        left = 4,
        right = 4,
        top = 4,
        bottom = 4,
      }
      config.initial_cols = 160
      config.initial_rows = 48
      config.window_decorations = "NONE"

      return config
    '';
  };
}
