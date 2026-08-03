{
  config,
  inputs,
  pkgs,
  ...
}: let
  tomlFormat = pkgs.formats.toml {};

  # Same source kitty's font comes from — stylix sets programs.kitty.font from
  # `stylix.fonts.monospace`, so reading the option here keeps Warp on whatever
  # the rice's terminal font is instead of pinning a second copy of the name.
  monoFont = config.stylix.fonts.monospace.name;

  # ── Why ~/.config/warp-oss and not ~/.config/warp-terminal ────────────────
  # We install upstream's own `warp-terminal-experimental` (built from the
  # `warp` flake input, see flake.nix for why we don't use nixpkgs' unfree
  # prebuilt tarball). That binary is the OSS build with app id
  # `dev.warp.WarpOss`, and Warp derives its config/state dirs from the app id
  # — so the live config is ~/.config/warp-oss/settings.toml and the state is
  # ~/.local/state/warp-oss/. Anything still sitting in ~/.config/warp-terminal
  # is leftover from a prebuilt build and is not read by this install.
  configDir = "warp-oss";

  # ── Why pinning settings.toml makes the in-app settings GUI non-persistent ─
  # Warp's TOML preference store (crates/warpui_extras/src/user_preferences/
  # toml_backed.rs) flushes with a plain in-place `std::fs::write(&file_path,
  # data)` — no write-to-temp + atomic rename. Following a /nix/store symlink
  # therefore fails with EROFS instead of clobbering the symlink, which is the
  # behaviour we want: the store copy always wins and HM activation never has
  # to fight a file Warp replaced behind our back.
  #
  # The consequence is that changing a setting in Warp's GUI applies for the
  # rest of the session (the value lives in the in-memory `DocumentMut`) but is
  # lost on restart. To change a setting for real, edit it here and re-run
  # `user-apply` — Warp hot-reloads settings.toml (crates/integration/src/test/
  # settings_file_hot_reload.rs), so the new value is picked up without a
  # restart.
  #
  # Note this is only about *writes*. Reads are unaffected: `load_document`
  # treats a missing or empty file as "no settings" and only inhibits writes
  # when the file fails to PARSE — and a `pkgs.formats.toml` build product is
  # parse-valid by construction, so `write_inhibited` never trips here.
  settings = {
    # ── Appearance ────────────────────────────────────────────────────────
    appearance = {
      themes = {
        # `adeberry` is one of Warp's bundled themes (app/src/themes/
        # default_themes.rs), not a file under ~/.config/warp-oss/themes — so
        # there is nothing extra to install alongside this name.
        system_theme = false;
        theme = "adeberry";
      };
      vertical_tabs.enabled = true;
      window.zoom_level = 250;
      text = {
        # `font_name` is the terminal font; `ai_font_name` is the one used for
        # agent-mode/AI output. Both are set explicitly rather than via
        # `match_ai_font = true`, because that flag is only honoured in the
        # settings-changed subscription (app/src/appearance.rs) — the startup
        # path `build_appearance` reads `ai_font_name` directly and ignores it,
        # so with the flag alone AI text would render in the bundled Hack until
        # something touched the font setting at runtime.
        #
        # An unresolvable name is not fatal: `get_or_load_font_family` logs a
        # warning and falls back to Hack.
        font_name = monoFont;
        ai_font_name = monoFont;

        # Sizes are deliberately NOT taken from `stylix.fonts.sizes.terminal`:
        # Warp scales all text by `window.zoom_level` (250% below) while kitty
        # has no such multiplier, so the two knobs aren't the same quantity and
        # copying the stylix value across would give ~2.5× the intended size.
        #
        # Both must stay Nix floats: Warp deserializes them into f32, and the
        # `toml` crate refuses an integer for a float field. Writing `14`
        # instead of `14.0` here would make Warp reject the whole key.
        notebook_font_size = 14.0;
        font_size = 13.0;
      };
    };

    # ── Agent mode ────────────────────────────────────────────────────────
    agents = {
      cloud_conversation_storage_enabled = true;
      third_party.should_render_cli_agent_toolbar = true;
      profiles.agent_mode_coding_permissions = "always_allow_reading";

      warp_agent = {
        is_any_ai_enabled = true;
        input.nld_in_terminal_enabled = false;
        other = {
          show_agent_notifications = true;
          show_conversation_history = true;
        };
      };

      execution_profiles.default = {
        name = "Default";
        # Server-side model UUID; the catalogue it indexes into is the
        # `AvailableLLMs` blob Warp caches in user_preferences.json (see the
        # note at the bottom of this file), so this id is only meaningful
        # against Warp's backend and can't be resolved locally.
        base_model = "ab356ae5-3516-40c1-a50a-40fb28e26cc2";

        apply_code_diffs = "always_ask";
        ask_user_question = "always_ask";
        autosync_plans_to_warp_drive = true;
        computer_use = "never";
        execute_commands = "agent_decides";
        read_files = "always_allow";
        run_agents = "always_ask";
        web_search_enabled = true;
        write_to_pty = "always_ask";

        # Empty allowlists + a denylist of everything that can spawn an
        # unreviewed shell (bash/fish/sh/zsh/pwsh, eval/exec/source), fetch
        # from the network (curl/wget), resolve names (dig/nslookup/host),
        # reach another machine (ssh/scp/rsync/telnet), or delete (rm). The
        # trailing `(\s.*)?` makes each entry match the bare command as well
        # as the command with arguments.
        command_allowlist = [];
        command_denylist = [
          ''bash(\s.*)?''
          ''fish(\s.*)?''
          ''pwsh(\s.*)?''
          ''sh(\s.*)?''
          ''zsh(\s.*)?''
          ''curl(\s.*)?''
          ''eval(\s.*)?''
          ''exec(\s.*)?''
          ''source(\s.*)?''
          ''wget(\s.*)?''
          ''dig(\s.*)?''
          ''nslookup(\s.*)?''
          ''host(\s.*)?''
          ''ssh(\s.*)?''
          ''scp(\s.*)?''
          ''rsync(\s.*)?''
          ''telnet(\s.*)?''
          ''rm(\s.*)?''
        ];
        directory_allowlist = [];
        mcp_allowlist = [];
        mcp_denylist = [];
        mcp_permissions = "agent_decides";
      };
    };

    # ── Account ───────────────────────────────────────────────────────────
    account = {
      # Pinned off, matching Warp's own default (app/src/settings/
      # cloud_preferences.rs → `IsSettingsSyncEnabled { default: false }`), so
      # this is a no-op semantically — it's here to keep the cloud syncer from
      # ever becoming authoritative over this file. With sync on,
      # `maybe_sync_cloud_pref_to_local` would try to write cloud values back
      # into settings.toml on every startup and fail against the read-only
      # store path, i.e. a permanent losing fight logged once per launch.
      is_settings_sync_enabled = false;
    };

    # ── Privacy ───────────────────────────────────────────────────────────
    privacy = {
      # Carried over verbatim from the imperative config, where Warp itself
      # seeded them on first run (tracked by `HasInitializedDefaultSecretRegexes`
      # in user_preferences.json). Keeping them means that if that state file
      # is ever reset, the re-seed Warp attempts is a no-op against a file that
      # already matches — rather than a write it can't perform.
      #
      # They are inert while `secret_redaction.enabled = false` below.
      custom_secret_regex_list = [
        {
          name = "IPv4 Address";
          pattern = ''\b((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}\b'';
        }
        {
          name = "IPv6 Address";
          pattern = ''\b((([0-9A-Fa-f]{1,4}:){1,6}:)|(([0-9A-Fa-f]{1,4}:){7}))([0-9A-Fa-f]{1,4})\b'';
        }
        {
          name = "Phone Number";
          pattern = ''\b(\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}\b'';
        }
        {
          name = "MAC Address";
          pattern = ''\b((([a-zA-z0-9]{2}[-:]){5}([a-zA-z0-9]{2}))|(([a-zA-z0-9]{2}:){5}([a-zA-z0-9]{2})))\b'';
        }
        {
          name = "Google API Key";
          pattern = ''\bAIza[0-9A-Za-z-_]{35}\b'';
        }
        {
          name = "AWS Access ID";
          pattern = ''\b(AKIA|A3T|AGPA|AIDA|AROA|AIPA|ANPA|ANVA|ASIA)[A-Z0-9]{12,}\b'';
        }
        {
          name = "Slack App Token";
          pattern = ''\bxapp-[0-9]+-[A-Za-z0-9_]+-[0-9]+-[a-f0-9]+\b'';
        }
        {
          name = "GitHub Classic Personal Access Token";
          pattern = ''\bghp_[A-Za-z0-9_]{36}\b'';
        }
        {
          name = "GitHub Fine-Grained Personal Access Token";
          pattern = ''\bgithub_pat_[A-Za-z0-9_]{82}\b'';
        }
        {
          name = "GitHub OAuth Access Token";
          pattern = ''\bgho_[A-Za-z0-9_]{36}\b'';
        }
        {
          name = "GitHub User-to-Server Token";
          pattern = ''\bghu_[A-Za-z0-9_]{36}\b'';
        }
        {
          name = "GitHub Server-to-Server Token";
          pattern = ''\bghs_[A-Za-z0-9_]{36}\b'';
        }
        {
          name = "Stripe Key";
          pattern = ''\b(?:r|s)k_(test|live)_[0-9a-zA-Z]{24}\b'';
        }
        {
          name = "Firebase Auth Domain";
          pattern = ''\b([a-z0-9-]){1,30}(\.firebaseapp\.com)\b'';
        }
        {
          name = "JWT";
          pattern = ''\b(ey[a-zA-z0-9_\-=]{10,}\.){2}[a-zA-z0-9_\-=]{10,}\b'';
        }
        {
          name = "OpenAI API Key";
          pattern = ''\bsk-[a-zA-Z0-9]{48}\b'';
        }
        {
          name = "Anthropic API Key";
          pattern = ''\bsk-ant-api\d{0,2}-[a-zA-Z0-9\-]{80,120}\b'';
        }
        {
          name = "Generic SK API Key";
          pattern = ''\bsk-[a-zA-Z0-9\-]{10,100}\b'';
        }
        {
          name = "Fireworks API Key";
          pattern = ''\bfw_[a-zA-Z0-9]{24}\b'';
        }
        {
          name = "Warp API Key";
          pattern = ''\bwk-[0-9]+\.[A-Fa-f0-9.\-]+\b'';
        }
      ];
      secret_redaction.enabled = false;

      # Left at Warp's defaults (true) rather than flipped, because in this
      # build they have nothing to gate: app/src/bin/oss.rs constructs the OSS
      # ChannelState with `telemetry_config: None` and
      # `crash_reporting_config: None`, so the RudderStack and Sentry wiring
      # these two flags feed is never constructed. Flipping them to false is a
      # harmless belt-and-braces change if the OSS build ever grows a reporter.
      telemetry_enabled = true;
      crash_reporting_enabled = true;
    };

    # ── General / code / Warp Drive ───────────────────────────────────────
    general = {
      default_session_mode = "agent";
      show_warning_before_quitting = false;
    };

    code.editor = {
      show_code_review_button = true;
      show_project_explorer = true;
      show_global_search = true;
    };

    warp_drive.enabled = true;

    # ── Notifications ─────────────────────────────────────────────────────
    notifications = {
      toast_duration_secs = 8;
      preferences = {
        is_agent_task_completed_enabled = true;
        is_long_running_enabled = true;
        is_needs_attention_enabled = true;
        is_password_prompt_enabled = true;
        long_running_threshold = 30;
        mode = "dismissed";
        play_notification_sound = true;
      };
    };

    # ── Terminal ──────────────────────────────────────────────────────────
    terminal.osc52_clipboard_access = "write_only";
  };
in {
  # Warp built from upstream's own flake (`warp-oss`), not nixpkgs' unfree
  # prebuilt tarball — see the `warp` input in flake.nix for the full reasoning
  # (no autoupdate banner, no telemetry/crash-reporting wiring).
  home.packages = [
    inputs.warp.packages.${pkgs.stdenv.hostPlatform.system}.warp-terminal-experimental
  ];

  # Generated from the `settings` attrset above rather than a checked-in
  # settings.toml blob, so the config is Nix values we can comment, reuse and
  # let the TOML writer type-check — not an opaque file we merely copy.
  xdg.configFile."${configDir}/settings.toml".source =
    tomlFormat.generate "warp-settings.toml" settings;

  # ── Deliberately NOT managed: user_preferences.json ─────────────────────
  # The sibling ~/.config/warp-oss/user_preferences.json is state, not config:
  # ~200 KB of which ~174 KB is `AvailableLLMs`, a model catalogue Warp fetches
  # from its backend and rewrites, plus `AvailableHarnesses`, AI request quota
  # counters, the `SettingsFileLastSyncedHash`, an `ExperimentId`, and a pile of
  # one-shot onboarding/dismissal flags (`HasCompletedOnboarding`,
  # `DidShowOzLaunchModal`, …). None of it is user-authored, all of it is
  # written back at runtime, so it stays a plain writable file.
}
