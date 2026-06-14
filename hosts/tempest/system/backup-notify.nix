{ pkgs, lib, ... }:
#
# Desktop notifications for the backup/scrub units that exist on both the real
# laptop AND the VM: the weekly rpool integrity scrub (services.zfs.autoScrub →
# zfs-scrub.service, system/zfs.nix) and the daily offsite Borg run
# (borgbackup-job-home-irene.service, system/services.nix). Both do real work on
# every run, so a notification on each outcome is wanted.
#
# These replace the old always-on bar health readout, which Noctalia v5 can no
# longer drive (see packages/backup-notify.nix and rices/niri/noctalia-widgets.nix).
#
# The third backup leg — the external USB pool — only exists on the physical
# host, so its failure wiring and its (skip-aware) success notification live in
# the physical-only system/backup-external.nix instead.
let
  backup-notify = pkgs.callPackage ../../../packages/backup-notify.nix { };

  # A oneshot that fires exactly one notification. `result` is ok|fail, `label`
  # the human name, `unit` the monitored unit (named in the failure body).
  notifier = { result, label, unit }: {
    description = "Desktop ${result} notification: ${label}";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.escapeShellArgs [
        "${backup-notify}/bin/backup-notify"
        result
        label
        unit
      ];
    };
  };

  # Scrub completion needs more than a bare OnSuccess: `zpool scrub -w` (what the
  # autoScrub unit runs) waits for the scrub to finish but still exits 0 when it
  # FOUND corruption — so "the unit succeeded" does not mean "the pool is clean".
  # Inspect pool health afterwards via `zpool status -x` (the same signal the old
  # bar readout used) and report ok/fail accordingly. rpool is the only pool
  # normally imported; the external `backup` pool is exported except during its
  # own run (which carries its own scrub + health check).
  scrubNotify = pkgs.writeShellApplication {
    name = "backup-notify-scrub";
    runtimeInputs = [ backup-notify pkgs.zfs pkgs.gnugrep ];
    text = ''
      pool=rpool
      if zpool status -x "$pool" 2>/dev/null | grep -q "is healthy"; then
        backup-notify ok "ZFS scrub ($pool)" zfs-scrub.service
      else
        backup-notify fail "ZFS scrub ($pool)" zfs-scrub.service
      fi
    '';
  };
in
{
  systemd.services = {
    backup-notify-scrub = {
      description = "Desktop notification: ZFS scrub result";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${scrubNotify}/bin/backup-notify-scrub";
      };
    };
    # Reached only if `zpool scrub -w` itself errored (e.g. pool unavailable);
    # a scrub that ran but found errors is caught by backup-notify-scrub above.
    backup-notify-scrub-fail = notifier {
      result = "fail";
      label = "ZFS scrub (rpool)";
      unit = "zfs-scrub.service";
    };

    backup-notify-borg-ok = notifier {
      result = "ok";
      label = "Borg offsite backup";
      unit = "borgbackup-job-home-irene.service";
    };
    backup-notify-borg-fail = notifier {
      result = "fail";
      label = "Borg offsite backup";
      unit = "borgbackup-job-home-irene.service";
    };

    # Merge OnSuccess=/OnFailure= into the units the zfs / borgbackup modules
    # generate.
    zfs-scrub.onSuccess = [ "backup-notify-scrub.service" ];
    zfs-scrub.onFailure = [ "backup-notify-scrub-fail.service" ];

    borgbackup-job-home-irene.onSuccess = [ "backup-notify-borg-ok.service" ];
    borgbackup-job-home-irene.onFailure = [ "backup-notify-borg-fail.service" ];
  };
}
