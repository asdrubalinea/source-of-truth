{ pkgs, lib, config, ... }:
let
  niri = "${pkgs.niri-unstable}/bin/niri";
  jq = "${pkgs.jq}/bin/jq";

  # niri has no "sticky / show on all workspaces" window flag (checked against
  # v25.08 and the latest wiki — the maintainer lists it only as a *future*
  # idea). Floating windows — which our Picture-in-Picture window-rule makes the
  # PiP — live on a single workspace ("each workspace has its own floating
  # layout"), so the PiP is stuck on whichever workspace the browser is on.
  #
  # This daemon fakes stickiness: it watches niri's event stream and, whenever
  # the focused workspace changes (or a window opens/changes), moves any PiP
  # window onto the now-focused workspace. `--focus false` moves it without
  # stealing focus, so the video just appears wherever you are.
  #
  # Matching: the PiP window has NO app-id under Chrome (verified via
  # `niri msg windows`: app_id ""), matching the title-only window-rule in
  # ./window-rules.nix. We match the title anchored — Chrome uses
  # "Picture in picture", Firefox/Zen use "Picture-in-Picture" — so an ordinary
  # window that merely *mentions* the phrase (e.g. a terminal titled after a
  # task) is never grabbed.
  #
  # Target reference: `move-window-to-workspace <idx>` resolves the index on the
  # *focused* monitor, and the just-focused workspace is by definition on the
  # focused monitor at that idx — so passing the focused workspace's `idx` is
  # correct whether one or several monitors are connected.
  pipFollow = pkgs.writeShellScript "niri-pip-follow" ''
    set -u

    reconcile() {
      ws=$(${niri} msg --json workspaces) || return 0
      fid=$(printf '%s' "$ws" | ${jq} -r 'first(.[] | select(.is_focused) | .id) // empty')
      fidx=$(printf '%s' "$ws" | ${jq} -r 'first(.[] | select(.is_focused) | .idx) // empty')
      [ -n "$fid" ] || return 0

      ${niri} msg --json windows \
        | ${jq} -r --argjson fid "$fid" '
            .[]
            | select(.title != null and (.title | test("^picture[- ]in[- ]picture$"; "i")))
            | select(.workspace_id != $fid)
            | .id
          ' \
        | while IFS= read -r wid; do
            [ -n "$wid" ] || continue
            ${niri} msg action move-window-to-workspace \
              --window-id "$wid" --focus false "$fidx" || true
          done
    }

    # Catch a PiP that's already open when the daemon (re)starts.
    reconcile

    # React to workspace switches and window open/change events. The stream ends
    # only when niri exits; systemd then restarts us (Restart=always).
    ${niri} msg --json event-stream | while IFS= read -r line; do
      case "$line" in
        *WorkspaceActivated*|*WorkspacesChanged*|*WindowOpenedOrChanged*) reconcile ;;
      esac
    done
  '';
in
lib.mkIf config.rices.niri.enable {
  systemd.user.services.niri-pip-follow = {
    Unit = {
      Description = "Keep the Picture-in-Picture window on the focused niri workspace";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pipFollow}";
      Restart = "always";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
