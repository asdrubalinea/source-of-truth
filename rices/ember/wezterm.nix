{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.rices.ember.enable {
  programs.wezterm = {
    enable = true;

    # The tab bar's fills, unpicked. stylix's wezterm target gives every
    # INACTIVE tab a solid base03 background (and the same to the new-tab
    # button) — base03 is the comment colour, bright enough that four open tabs
    # put a row of lit warm-grey blocks across the top of the window. That is
    # both the loudest thing in the terminal and permanently lit content on an
    # OLED, which is what principle 3 and ADR 0009 exist to prevent.
    #
    # Replaced with a tab bar that is text on the buffer's own ground: the
    # active tab is `base05`, the inactive ones `base03` as FOREGROUND, and
    # hovering lifts the text rather than filling the cell. Which tab is
    # focused is then carried by value, on characters that were going to be
    # drawn anyway. active_tab already matched and is left alone.
    #
    # Nix rather than the Lua below: extraConfig's returned table is merged
    # SHALLOWLY over these settings (see home-manager's wezterm module), so
    # setting `config.colors` there would replace stylix's whole `colors` table
    # instead of this one leaf. `settings` is `attrsOf anything`, which merges
    # per-attribute, so mkForce lands exactly where it is aimed.
    settings.colors.tab_bar = with config.lib.stylix.colors.withHashtag; {
      background = lib.mkForce base00;
      inactive_tab_edge = lib.mkForce base00;
      inactive_tab = lib.mkForce {
        bg_color = base00;
        fg_color = base03;
      };
      inactive_tab_hover = lib.mkForce {
        bg_color = base00;
        fg_color = base05;
      };
    };

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

      -- Disambiguated key reporting (CSI u) off: any program that asks for the
      -- kitty protocol and exits without resetting it leaves the shell — most
      -- painfully a plain ssh session on a host whose readline doesn't parse
      -- CSI u — echoing raw sequences instead of editing the line. Helix loses
      -- Shift+Enter / Ctrl+Enter / Ctrl+; disambiguation; that is the trade.
      config.enable_kitty_keyboard = false

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
      local function face(weight, italic)
        return wezterm.font_with_fallback {
          { family = "${config.stylix.fonts.monospace.name}", weight = weight, italic = italic },
          "Symbols Nerd Font Mono",
          "${config.stylix.fonts.emoji.name}",
        }
      end
      config.font = face("Regular", false)

      -- The intensity ladder, pinned rather than inferred. Left alone, wezterm
      -- answers SGR 2 (dim) and SGR 1 (bold) by asking fontconfig for a lighter
      -- or heavier cut of the family. That was harmless while the body face
      -- shipped two weights and is wrong now that it ships seven: JuliaMono gave
      -- dim the *Light* cut and bold the *ExtraBold* one. Dim text is already
      -- blended toward the ground, so drawing it in the thinnest cut in the
      -- family stacks the two losses — and an agent TUI is mostly dim text.
      -- Measured off a screenshot of this terminal: 3-11% of the ink on a dim
      -- line reached full colour, against 56% on a bold one.
      config.font_rules = {
        { intensity = "Half", italic = false, font = face("Regular", false) },
        { intensity = "Half", italic = true, font = face("Regular", true) },
        { intensity = "Bold", italic = false, font = face("Bold", false) },
        { intensity = "Bold", italic = true, font = face("Bold", true) },
      }

      -- A readability floor, in WCAG terms, applied at draw time. Anything the
      -- pane asks for that lands under 4.5:1 against the cell behind it gets
      -- lifted until it clears — SGR 2 (dim), which wezterm renders by blending
      -- the foreground toward the ground, and base03 comments, which sit at
      -- 3.6:1 on a pure-black ground by design.
      --
      -- Deliberately here and not in the palette: ./ember-3400k-dark.yaml dims
      -- base03 on purpose, and helix, emacs and the bar are all reading text on
      -- surfaces that are not pure black, where it measures fine. This is the
      -- terminal paying for base00 being 000000 (ADR 0009) rather than the whole
      -- rice giving up the darkest ground it has.
      config.text_min_contrast_ratio = 4.5

      -- Cursor. Block, not bar — see ./kitty.nix for why. "Steady" is the
      -- non-blinking half of the name and stays.
      config.default_cursor_style = "SteadyBlock"

      -- Tabs.
      --
      -- The retro tab bar draws in the terminal font/grid, which suits
      -- window_decorations = "NONE" (the fancy bar expects a titlebar) and is
      -- the variant stylix colours via colors.tab_bar.
      config.use_fancy_tab_bar = false
      config.hide_tab_bar_if_only_one_tab = true
      config.tab_max_width = 32
      -- No "+" button. It is a permanently lit cell whose only function is
      -- already on CTRL+SHIFT+T, and it was the last thing in the strip still
      -- drawing a fill (see the tab_bar colours above).
      config.show_new_tab_button_in_tab_bar = false
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

        -- Shift+Enter → newline instead of submit in claude-code / codex.
        -- With enable_kitty_keyboard = false there is no CSI u to tell
        -- Shift+Enter apart from Enter, so both TUIs see a bare CR and send
        -- the message. ESC+CR is the meta-Enter sequence they already accept
        -- as "insert newline", and tmux forwards it untouched.
        { key = "Enter", mods = "SHIFT", action = act.SendString "\x1b\r" },
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
      --
      -- 12, not 4. Text that begins four pixels from a window edge reads as
      -- cramped however good the face is, and the inset is the cheap half of
      -- this look: it buys nothing but UNLIT pixels, which on this panel is a
      -- saving rather than a cost (docs/adr/0009).
      --
      -- Padding is a rice-wide behavioural value, so the same 12 is in
      -- ./kitty.nix, ./alacritty.nix and ./konsole.nix — changing one of the
      -- four is a divergence, not a change
      -- (docs/ember-visual-language.md, "A terminal").
      config.window_padding = {
        left = 12,
        right = 12,
        top = 12,
        bottom = 12,
      }
      -- No initial_cols/initial_rows: both compositors tile every window, so the
      -- requested grid is never honoured anyway — and under mango it is actively
      -- harmful. mango maps the window first (configure 0x0), then sends the tile
      -- size and the output's fractional scale (2, ceil of 1.5) in the same
      -- batch; wezterm acks the tile, then re-asserts the initial 160x48 grid at
      -- the new scale and commits a buffer smaller than the tile. The border is
      -- drawn at the tile, so the window looks correct but the wallpaper shows
      -- through on the right and bottom. Verified with WAYLAND_DEBUG=1: buffer
      -- 4168x2744 for a 2548x1436 tile with these set, 5096x2872 without.
      config.window_decorations = "NONE"

      return config
    '';
  };
}
