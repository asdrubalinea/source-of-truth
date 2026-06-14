# Fire a single desktop notification reporting a backup/scrub result, from a
# system (root) service into the graphical user's session.
#
# Background: the noctalia bar used to carry a live storage/backup-health
# readout, but Noctalia v5's custom_button can no longer poll a script (see
# rices/niri/noctalia-widgets.nix). Push notifications replace that pull readout
# — each backup/scrub unit reports success or failure as it finishes.
#
# Self-contained: it reaches into the user's session bus itself, so it can be
# driven from systemd OnSuccess=/OnFailure= handlers (which run as root) and
# called inline from a root orchestrator script alike.
#
#   Usage: backup-notify <ok|fail> <label> <unit>
#     label  human name shown in the notification (e.g. "Borg offsite backup")
#     unit   systemd unit, named in the failure body so the journal is one
#            copy-paste away
{ writeShellApplication
, libnotify
, util-linux
, coreutils
}:

writeShellApplication {
  name = "backup-notify";
  runtimeInputs = [ libnotify util-linux coreutils ];
  text = ''
    result=''${1:?usage: backup-notify <ok|fail> <label> <unit>}
    label=''${2:?usage: backup-notify <ok|fail> <label> <unit>}
    unit=''${3:?usage: backup-notify <ok|fail> <label> <unit>}

    # The graphical user to notify. The whole flake is single-user, so this is
    # hard-coded like the rest of the tree (scripts/*); override via the env if
    # ever reused elsewhere.
    target=''${BACKUP_NOTIFY_USER:-irene}

    if [ "$result" = ok ]; then
      urgency=low
      icon=dialog-information
      summary="$label completed"
      body="Finished successfully."
      expire=8000
    else
      urgency=critical
      icon=dialog-error
      summary="$label FAILED"
      body="See: journalctl -u $unit -e"
      expire=0   # 0 = until dismissed; a failure should not auto-clear
    fi

    # Deliver onto the target user's session bus. These handlers run as root, so
    # drop to the user and point GDBus at their runtime bus explicitly. If nobody
    # is logged in there is no bus socket (e.g. a 03:00 scrub while the laptop is
    # off, caught up later by the persistent timer) and thus no daemon to receive
    # the notification — skip quietly rather than fail the handler.
    uid=$(id -u "$target")
    runtime="/run/user/$uid"
    [ -S "$runtime/bus" ] || exit 0

    runuser -u "$target" -- env \
      XDG_RUNTIME_DIR="$runtime" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus" \
      notify-send \
        --app-name="Backups" \
        --urgency="$urgency" \
        --icon="$icon" \
        --expire-time="$expire" \
        "$summary" "$body"
  '';
}
