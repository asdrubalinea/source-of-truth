{
  pkgs,
  inputs,
  lib,
  config,
  ...
}: let
  colors = config.lib.stylix.colors;

  drift = pkgs.callPackage ../../packages/drift.nix {src = inputs.drift;};

  # --always-new-process twice over: it keeps `--class` ours (an existing
  # instance would spawn the window with its own app-id and miss the
  # open-fullscreen rule), and it makes $! the PID that owns the window.
  driftStart = pkgs.writeShellScript "drift-screensaver-start" ''
    ${pkgs.wezterm}/bin/wezterm start --always-new-process --class drift-screensaver -- ${drift}/bin/drift --scene waveform &
    echo $! > "$XDG_RUNTIME_DIR/drift-screensaver.pid"
  '';

  # RULE FOR EVERY SCRIPT IN THIS FILE: absolute store paths or bash builtins
  # only. swayidle inherits the systemd user-manager PATH, which has no
  # coreutils — a bare `cat` here silently read empty and leaked the
  # screensaver window on every resume. `$(< file)` is the builtin.
  driftStop = pkgs.writeShellScript "drift-screensaver-stop" ''
    pidfile="$XDG_RUNTIME_DIR/drift-screensaver.pid"
    if [ -f "$pidfile" ]; then
      kill "$(< "$pidfile")" 2>/dev/null || true
      ${pkgs.coreutils}/bin/rm -f "$pidfile"
    fi
  '';

  # swaylock, NOT Noctalia's lockscreen: Noctalia's ext-session-lock client
  # segfaults on output hotplug, and docking IS hotplug, so every lock taken
  # docked left niri painting its red fallback. Same reasoning as ADR 0007's
  # cold-boot move to tuigreet. PAM service `swaylock` is in ./system.nix.
  swaylockArgs = lib.concatStringsSep " " [
    "-f" # daemonize, but only AFTER the lock surface is up (see lockBeforeSleep)
    "--ignore-empty-password"
    "--show-failed-attempts"
    # NOT `--indicator`: no such option in 1.8.6, and getopt_long's prefix
    # matching makes it ambiguous against the --indicator-* flags, so swaylock
    # printed usage and exited 1 — every lock was a silent no-op.
    "--indicator-idle-visible"
    "--color ${colors.base00}"
    "--inside-color ${colors.base01}"
    "--inside-wrong-color ${colors.base08}"
    "--ring-color ${colors.base03}"
    "--ring-ver-color ${colors.base0D}"
    "--ring-wrong-color ${colors.base08}"
    "--key-hl-color ${colors.base0D}"
    "--bs-hl-color ${colors.base08}"
    "--text-color ${colors.base05}"
  ];
  swaylock = "${pkgs.swaylock}/bin/swaylock ${swaylockArgs}";

  # `lock` event entry point, fired by every logind Lock signal (the 600s timer
  # and Mod+L). Guarded because only one client may hold the session lock.
  lockNow = pkgs.writeShellScript "ember-lock" ''
    ${pkgs.procps}/bin/pidof swaylock > /dev/null 2>&1 && exit 0
    exec ${swaylock}
  '';

  # swayidle holds the logind sleep inhibitor only until this RETURNS, so the
  # lock must be up before we let go. `swaylock -f` forks only after taking the
  # lock, which is exactly that guarantee — going via `loginctl lock-session`
  # instead put the lock on the separate, un-inhibited `lock` event and let the
  # box suspend unlocked.
  lockBeforeSleep = pkgs.writeShellScript "ember-lock-before-sleep" ''
    ${pkgs.procps}/bin/pidof swaylock > /dev/null 2>&1 || ${swaylock}
    # Machine furniture (the desk lamp) goes here, inside the inhibitor, and
    # not on an idle timeout: suspend stops the idle clock, so a timer far
    # enough out to mean "nobody is here" never arrives.
    ${lib.concatStringsSep "\n" config.rices.ember.beforeSleepCommands}
    # Small settle before the screen is frozen for s2idle.
    ${pkgs.coreutils}/bin/sleep 0.3
  '';

  # --- Monitor power, per session ------------------------------------------
  # swayidle is furniture: one user service for both compositor layers. Every
  # command here is compositor-agnostic except powering panels off, so this
  # dispatches on the socket each compositor exports (the same variable
  # Noctalia detects on) rather than duplicating the unit.
  #
  # Two traps in the mango arm:
  #
  #  - `get all-monitors` answers {"monitors":[...]}, not a bare array. Filtering
  #    `.[].name` makes jq error and the loop silently never runs.
  #  - NEVER TOUCH A MONITOR KANSHI DISABLED. `wakeup_monitor` is unconditional,
  #    so waking the kanshi-disabled lid panel re-adds it with layout_add_auto —
  #    wherever mango picks, not where kanshi put it ("resume, layout is fucked").
  #    Distinguish them by geometry, not `active` (which means "is selected"):
  #    kanshi-disabled is out of the layout and reports width 0; slept by us
  #    stays in and reports real geometry. `select(.width > 0)` is therefore
  #    "monitors this session may drive", in both directions, with no state to
  #    keep between calls — but it only holds with the only_sleep patch applied
  #    in flake.nix, without which kanshi churn ejected the slept panel for good.
  #
  # Panels in rices.ember.ddcSleepMonitors go through their scaler (DDC/CI, VCP
  # D6) instead: DPMS-off cuts the DP signal, and a bus-powered panel then drops
  # off the bus and reconnects lit, churning kanshi profiles mid-sleep. D6 keeps
  # the link up — dark, still enumerated, wakes on d6=1. --noverify because the
  # BOE NAKs the read-back while entering standby; the retry covers i2c flock
  # collisions with noctalia's brightness polling. Connector names are
  # incidental, so the policy matches ddcutil's MFG:model:serial id and resolves
  # the connector at runtime.
  ddcMonitors = config.rices.ember.ddcSleepMonitors;
  ddcutil = "${pkgs.ddcutil}/bin/ddcutil";
  awk = "${pkgs.gawk}/bin/awk";
  monitorPower = pkgs.writeShellScript "ember-monitor-power" ''
    set -u
    case "''${1:-off}" in
      off) niri_action=power-off-monitors; mango_action=sleep_monitor; ddc_value=4 ;;
      on)  niri_action=power-on-monitors;  mango_action=wakeup_monitor; ddc_value=1 ;;
      *) exit 2 ;;
    esac

    if [ -n "''${NIRI_SOCKET:-}" ]; then
      exec ${pkgs.niri-unstable}/bin/niri msg action "$niri_action"
    elif [ -n "''${MANGO_INSTANCE_SIGNATURE:-}" ]; then
      # Lines of "<connector>\t<i2c bus>\t<MFG:model:serial>", one per panel
      # ddcutil can talk to. `-F': +'` keeps the colons inside the id intact.
      ddc_table=""
      ${lib.optionalString (ddcMonitors != []) ''
      ddc_table=$(${ddcutil} detect --brief 2>/dev/null \
        | ${awk} -F': +' '
            $1 ~ /I2C bus/       { bus = $2 }
            $1 ~ /DRM connector/ { conn = $2; sub(/^card[0-9]+-/, "", conn) }
            $1 ~ /Monitor/       { printf "%s\t%s\t%s\n", conn, bus, $2 }')
    ''}
      ${pkgs.mango}/bin/mmsg get all-monitors \
        | ${pkgs.jq}/bin/jq -r '.monitors[] | select(.width > 0) | .name' \
        | while read -r mon; do
            ddc_id=$(printf '%s\n' "$ddc_table" | ${awk} -F'\t' -v m="$mon" '$1 == m {print $3}')
            if [ -n "$ddc_id" ] && printf '%s\n' ${lib.escapeShellArgs ddcMonitors} \
                | ${pkgs.gnugrep}/bin/grep -Fxq "$ddc_id"; then
              bus=$(printf '%s\n' "$ddc_table" | ${awk} -F'\t' -v m="$mon" '$1 == m {print $2}')
              bus="''${bus#/dev/i2c-}"
              ${ddcutil} --bus "$bus" --noverify setvcp d6 "$ddc_value" \
                || ${ddcutil} --bus "$bus" --noverify setvcp d6 "$ddc_value" || true
            else
              ${pkgs.mango}/bin/mmsg dispatch "$mango_action,$mon" || true
            fi
          done
    fi
  '';

  # Suspend on battery only: on AC the machine stays awake (bots, backups) with
  # just the screens off. Reads sysfs directly. `BAT*`, not `*` — peripheral
  # batteries live in the same directory and a mouse at Full would veto every
  # suspend. `$(< …)`, not `cat`, per the store-path rule above; the bare `cat`
  # this used to call meant idle suspend never once fired.
  suspendOrOnBattery = pkgs.writeShellScript "ember-suspend-or-not" ''
    for s in /sys/class/power_supply/BAT*/status; do
      [ -r "$s" ] || continue
      [ "$(< "$s")" != "Discharging" ] && exit 0
    done
    exec ${pkgs.systemd}/bin/systemctl suspend
  '';

  # ps5-audio's pw-loopback runs whether or not there is signal, so the
  # inhibitor below read "audio is playing" forever and the panels never slept
  # again — the "idle randomly stops working until I reboot" bug. Blacklisting
  # the node is the whole fix. `name` is a regex over what Helvum shows
  # (description ?? nick ?? node.name), NOT node.name — so it is the unit name
  # here, and the obvious "^output\\.ps5-audio$" silently matches nothing.
  # due-cuffie's combine sink is the same shape if it ever strands idle too.
  inhibitConfig = (pkgs.formats.toml {}).generate "wayland-pipewire-idle-inhibit.toml" {
    node_blacklist = [{name = "^ps5-audio$";}];
  };
in
  lib.mkIf config.rices.ember.enable {
    services.swayidle = {
      enable = true;
      systemdTargets = ["graphical-session.target"];
      timeouts = [
        {
          timeout = 300;
          command = "${driftStart}";
          resumeCommand = "${driftStop}";
        }
        {
          timeout = 600;
          command = "${pkgs.systemd}/bin/loginctl lock-session";
        }
        {
          # OLED anti burn-in, and the earliest timer on purpose — a dark panel
          # is the best protection, which makes the 300s screensaver and 600s
          # lock effectively unreachable on-screen (kept for the manual paths).
          timeout = 120;
          command = "${monitorPower} off";
          resumeCommand = "${monitorPower} on";
        }
        {
          # Nothing else here suspends on inactivity — logind only acts on the
          # lid — so without this the laptop sits awake and draining with its
          # screen off. See suspendOrOnBattery: no-op on AC.
          timeout = 1200;
          command = "${suspendOrOnBattery}";
        }
      ];
      events = {
        before-sleep = "${lockBeforeSleep}";
        lock = "${lockNow}";

        # The manual "restart kanshi after every resume", automated: resume
        # re-enumerates the external panels and mango enables + auto-places a
        # fresh output. kanshi won't fix it alone — its match ignores
        # enabled/mode/position, so the profile still matches and nothing is
        # re-applied. `reload` clears current_profile first, forcing a full
        # commit, without dropping the wayland connection a restart would.
        # Harmless under niri, so it needs no compositor test.
        after-resume = "${pkgs.kanshi}/bin/kanshictl reload";
      };
    };

    # Chrome takes no Wayland idle inhibitor for in-page playback, so panels
    # went dark 120s into a video. Rather than one rule per browser, inhibit on
    # what every video has in common: sound.
    #
    # This must be wayland-pipewire-idle-inhibit and NOT sway-audio-idle-inhibit,
    # which despite its name and nixpkgs description contains no Wayland client
    # at all (no libwayland, no zwp_idle_inhibit symbols) — it takes a *logind*
    # inhibitor, which swayidle's Wayland-protocol timers cannot see. It looked
    # proven because the nested-mango test that validated the inhibit path used
    # `wlinhibit`. Verify the protocol, not the package name.
    #
    # `-w` is spelled out though it is the default, for that reason. -d 5 (the
    # default) ignores streams under 5s, so notification blips don't hold the
    # panels awake. Ceiling: a muted video produces no stream and still times
    # out; the next rung would be mango's idleinhibit_when_focus, which is a
    # worse deal (inhibits whenever focused, video or not).
    #
    # Being a real Wayland client it dies with the compositor, so it is in the
    # restart-policy list in homes/tempest/default.nix beside swayidle/kanshi.
    systemd.user.services.wayland-pipewire-idle-inhibit = {
      Unit = {
        Description = "Hold a Wayland idle inhibitor while pipewire is playing audio";
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${pkgs.wayland-pipewire-idle-inhibit}/bin/wayland-pipewire-idle-inhibit -w -c ${inhibitConfig}";
        Restart = "always";
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  }
