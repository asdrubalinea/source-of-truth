{
  pkgs,
  lib,
  ...
}:
#
# The LOCAL leg of a 3-2-1 backup: ZFS replication of the irreplaceable datasets
# onto an encrypted pool on an external USB SSD.
#
#   sanoid (system/zfs.nix) ── local instant-rollback snapshots
#   syncoid (here) ─────────── full versioned history on the USB SSD  ← this file
#   borg (system/services.nix) ─ offsite /home to the Hetzner storagebox
#
# ZFS send/recv rather than a second borg repo because it is block-level
# incremental (a daily run is seconds, not a file re-walk), it preserves every
# sanoid snapshot so any point in time stays browsable via `httm` or
# `.zfs/snapshot/`, and recovery from a dead NVMe is one `zfs send` back.
#
# ──────────────────────────────────────────────────────────────────────────
# ONE-TIME SETUP (destructive — do NOT let a rebuild do this; run by hand):
#
#   # 0. Pick a passphrase, store it in vaultwarden/bitwarden FIRST (see the
#   #    "key survival" note below), then write it to the on-disk key file:
#   sudo install -d -m 700 /persist/backup
#   printf '%s' 'YOUR-STRONG-PASSPHRASE' | sudo tee /persist/backup/backup.key >/dev/null
#   sudo chmod 600 /persist/backup/backup.key
#
#   # 1. Identify the external SSD by its STABLE by-id path (never /dev/sdX):
#   ls -l /dev/disk/by-id/ | grep -i usb
#
#   # 2. Create the encrypted backup pool ON THE WHOLE DEVICE (wipes it):
#   sudo zpool create \
#     -o ashift=12 -o autotrim=on -o cachefile=none \
#     -O compression=zstd -O atime=off \
#     -O xattr=sa -O acltype=posixacl -O dnodesize=auto \
#     -O encryption=aes-256-gcm -O keyformat=passphrase \
#     -O keylocation=file:///persist/backup/backup.key \
#     -O mountpoint=none -O com.sun:auto-snapshot=false \
#     backup /dev/disk/by-id/<EXTERNAL-SSD-by-id>
#
#   # 3. Seed it (also runs automatically on plug-in once this module is built):
#   sudo systemctl start tempest-backup-external.service
#
# KEY SURVIVAL: the key file lives on /persist, i.e. on the very NVMe this
# backup protects — if that disk dies and the passphrase exists ONLY there, the
# backup is unrecoverable. Keep it in vaultwarden and/or printed too. Recovery:
#   zpool import -R /mnt/recover backup && zfs load-key -L prompt backup
#   (type the passphrase) && zfs send/receive back, or rsync out.
# ──────────────────────────────────────────────────────────────────────────
let
  pool = "backup";
  parent = "${pool}/tempest";
  altroot = "/mnt/backup";

  # Failures go through systemd OnFailure= below, so a crash anywhere in the run
  # is caught; success is emitted inline at the end of the orchestrator, so the
  # no-op skip paths (drive absent / already imported) stay silent.
  backup-notify = pkgs.callPackage ../../../packages/backup-notify.nix {};

  # The one place this unit is named: the systemd unit, the udev rule that
  # triggers it, the fail-notification argument, and backup-verify.sh — which is
  # a plain .sh file and receives the name through the prelude below.
  usbUnitName = "tempest-backup-external";
  usbUnit = "${usbUnitName}.service";

  # Integrity-scrub cadence for the backup pool. The pool is only importable
  # during a run, so a periodic scrub has to ride along with the backup
  # (scrub-if-stale, see the orchestrator script below).
  scrubMaxAgeSec = 30 * 24 * 3600; # 30 days

  # Separate non-recursive datasets rather than one recursive stream, because
  # /persist and /persist/home carry independent sanoid retention. /nix is
  # reproducible and rpool/sbctl regenerable, so neither is backed up.
  pairs = [
    {
      src = "rpool/persist";
      dst = "${parent}/persist";
    }
    {
      src = "rpool/persist/home";
      dst = "${parent}/persist/home";
    }
  ];

  # Prune-only retention ON THE BACKUP POOL, deliberately deeper than the NVMe
  # so the external is the long archive. autosnap=no: syncoid ships the
  # snapshots, sanoid here only expires them. The configdir needs only
  # sanoid.conf — sanoid finds its bundled defaults relative to its own binary.
  pruneConfDir = pkgs.writeTextDir "sanoid.conf" ''
    [${parent}/persist]
      use_template = backup
    [${parent}/persist/home]
      use_template = backup

    [template_backup]
      autoprune = yes
      autosnap = no
      hourly = 0
      daily = 30
      weekly = 16
      monthly = 24
      yearly = 0
  '';

  # The orchestrator. Runs as root (it drives zpool/zfs/syncoid/sanoid).
  backupBin = pkgs.writeShellApplication {
    name = "tempest-backup-external";
    runtimeInputs = [
      pkgs.zfs
      pkgs.sanoid
      pkgs.coreutils
      pkgs.gnugrep
      backup-notify
    ];
    text = ''
      log() { echo "[tempest-backup-external] $*"; }

      # Removable drive: import only for the run, export after. (cachefile=none,
      # so it never auto-imports or blocks boot when absent.) If it is ALREADY
      # imported, a human is browsing it — leave it untouched.
      if zpool list -H -o name ${pool} >/dev/null 2>&1; then
        log "pool '${pool}' already imported (manual session?); skipping."
        exit 0
      fi

      # Import read-write under an altroot so the replicated /persist and
      # /persist/home mountpoints can never collide with the live ones. -N: do
      # not mount anything. -d by-id: stable device path.
      mkdir -p ${altroot}
      if ! zpool import -N -R ${altroot} -d /dev/disk/by-id ${pool} 2>/dev/null; then
        log "backup drive not attached; nothing to do."
        exit 0
      fi
      trap 'zpool export ${pool} || true' EXIT
      log "imported '${pool}'."

      # Decrypt (keylocation=file:///persist/backup/backup.key, set at create).
      if [ "$(zfs get -H -o value keystatus ${pool})" != "available" ]; then
        zfs load-key ${pool}
      fi

      # Ensure the container dataset exists (children inherit its encryption).
      if ! zfs list -H -o name ${parent} >/dev/null 2>&1; then
        zfs create -o canmount=off -o mountpoint=none ${parent}
      fi

      # syncoid takes its own `syncoid_<host>_<ts>` snapshot on the source and
      # sends with -I, carrying every sanoid snapshot in between — that is the
      # browsable history. recvOptions=u: never mount on receive.
      #
      # That sync snapshot is what makes the NEXT run incremental, and it
      # survives arbitrary gaps, because sanoid's autoprune only expires its own
      # `autosnap_*` and so never removes the common base. Exactly one is kept.
      #
      # It is a snapshot and NOT a bookmark — `--create-bookmark` is opt-in and
      # unpassed, so `zfs list -t bookmark` is empty. Destroy that snapshot by
      # hand and the next run has no common base and must reseed the pool.
      ${lib.concatMapStringsSep "\n" (p: ''
          log "replicating ${p.src} -> ${p.dst}"
          syncoid --recvOptions=u --quiet ${p.src} ${p.dst}
        '')
        pairs}

      # Expire old snapshots on the backup per the deep-retention policy above.
      sanoid --configdir=${pruneConfDir} --prune-snapshots --verbose

      # This run is the only window the pool is imported, so a periodic scrub
      # has to ride along. -w blocks until it finishes and the oneshot has no
      # timeout, so on a scrub run the drive must stay attached for hours. The
      # completion time is stamped as a user property on the pool — it travels
      # with the drive and is readable exactly when needed — rather than parsed
      # out of the free-form `zpool status` scan line.
      last_scrub=$(zfs get -H -o value tempest:scrubbed ${pool} 2>/dev/null || echo "")
      now=$(date +%s)
      case "$last_scrub" in
        "" | "-") due=yes ;;
        *) if [ "$(( now - last_scrub ))" -ge ${toString scrubMaxAgeSec} ]; then due=yes; else due=no; fi ;;
      esac
      if [ "$due" = yes ]; then
        log "integrity scrub due (last=''${last_scrub:-never}); scrubbing '${pool}' — may take hours, keep the drive attached."
        zpool scrub -w ${pool}
        zfs set tempest:scrubbed="$(date +%s)" ${pool}
        log "scrub finished."
      fi

      # The only chance to check drive health, while the pool is imported. A
      # pool can read ONLINE yet carry checksum/read/write or scrub-found
      # errors, which `status -x` catches. A non-zero exit fails the unit, which
      # latches the syncoid leg as **failed** (CONTEXT.md).
      if ! zpool status -x ${pool} | grep -q "is healthy"; then
        log "POOL '${pool}' UNHEALTHY:"
        zpool status -v ${pool} || true
        exit 1
      fi

      # Reached only on a genuine run (the skip paths above exit 0 earlier), so a
      # success notification here never fires for a plug-less daily timer tick.
      backup-notify ok "USB external backup" ${usbUnit} || true
      log "done."
    '';
  };

  # Convenience: mount the backup read-only-ish for browsing/restore with httm,
  # then eject. (Browsing needs the pool imported and the key loaded.)
  browseBin = pkgs.writeShellApplication {
    name = "tempest-backup-browse";
    runtimeInputs = [
      pkgs.zfs
      pkgs.coreutils
    ];
    text = ''
      mkdir -p ${altroot}
      if ! zpool list -H -o name ${pool} >/dev/null 2>&1; then
        zpool import -R ${altroot} -d /dev/disk/by-id ${pool}
      fi
      if [ "$(zfs get -H -o value keystatus ${pool})" != "available" ]; then
        zfs load-key ${pool}
      fi
      zfs mount ${parent}/persist || true
      zfs mount ${parent}/persist/home || true
      echo "Backup mounted under ${altroot}."
      echo "  Browse snapshots:  httm -R ${altroot}/persist/home"
      echo "  Raw snapshot dirs: ${altroot}/persist/home/.zfs/snapshot/"
      echo "  When finished:     sudo tempest-backup-eject"
    '';
  };

  ejectBin = pkgs.writeShellApplication {
    name = "tempest-backup-eject";
    runtimeInputs = [pkgs.zfs];
    text = ''
      zpool export ${pool} && echo "'${pool}' exported — safe to unplug."
    '';
  };

  # On-demand "is my backup actually good?". The orchestrator's `zpool status -x`
  # gate only looks during a run; this answers at any time, and — unlike the run
  # — imports READ-ONLY and never loads the encryption key. The body is a plain
  # .sh file because it is long and full of ''${...} expansions that would need
  # escaping in a Nix indented string; config values are injected as a prelude,
  # so PAIRS derives from the same `pairs` list the orchestrator replicates and
  # adding a dataset extends the verification automatically.
  verifyBin = pkgs.writeShellApplication {
    name = "tempest-backup-verify";
    runtimeInputs = [
      pkgs.zfs
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.systemd
    ];
    text =
      ''
        POOL=${pool}
        PARENT=${parent}
        ALTROOT=${altroot}
        USB_UNIT=${usbUnit}
        SCRUB_MAX_AGE=${toString scrubMaxAgeSec}
        PAIRS=(${lib.concatMapStringsSep " " (p: "${p.src}:${p.dst}") pairs})
      ''
      + builtins.readFile ./backup-verify.sh;
  };
in {
  environment.systemPackages = [
    backupBin
    browseBin
    ejectBin
    verifyBin
  ];

  # Fire a backup the moment the drive is plugged in. ZFS labels the member
  # partition with the pool name, so this matches our drive on any USB port.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_TYPE}=="zfs_member", ENV{ID_FS_LABEL}=="${pool}", TAG+="systemd", ENV{SYSTEMD_WANTS}="${usbUnit}"
  '';

  systemd.services.${usbUnitName} = {
    description = "Replicate ZFS snapshots to the external USB backup pool";
    # No wantedBy: started only on plug-in (udev, above) or by the timer below.
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${backupBin}/bin/tempest-backup-external";
    };
    # Any failure (mid-run crash or the explicit unhealthy-pool exit 1) raises a
    # desktop notification. Success is notified inline by the orchestrator so a
    # plug-less timer tick (which no-ops, exiting 0) stays silent.
    onFailure = ["backup-notify-usb-fail.service"];
  };

  systemd.services.backup-notify-usb-fail = {
    description = "Desktop fail notification: USB external backup";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.escapeShellArgs [
        "${backup-notify}/bin/backup-notify"
        "fail"
        "USB external backup"
        usbUnit
      ];
    };
  };

  # Daily fallback for "left it plugged in" — no-ops cleanly when the drive is
  # absent. Persistent catches a missed run after the laptop was off/asleep.
  systemd.timers.${usbUnitName} = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
