{
  config,
  lib,
  pkgs,
  hostname,
  ...
}:
# Read-only Vaultwarden mirror: pull the primary's exported snapshot over SSH
# and apply it to the local store before vaultwarden starts, then on a timer.
#
# This module was two byte-identical 142-line copies (tempest + hydra) that
# differed in exactly two lines: the SSH key path and a description string. The
# key path is the only real per-host fact, so it is the only option; the label
# is derived from `hostname`.
#
# The primary is orchid — see hosts/orchid/system/vaultwarden-export.nix, which
# writes the snapshot this pulls.
let
  cfg = config.services.vaultwarden-mirror;

  primaryHost = "orchid";
  primaryUser = "vwbackup";
  remoteSnapshot = "/persist/vaultwarden-export/current/";

  localData = "/var/lib/vaultwarden";
  localIncoming = "/var/lib/vaultwarden-mirror/incoming";
  sshStateDir = "/var/lib/vaultwarden-mirror/ssh";
  sshKnownHosts = "${sshStateDir}/known_hosts";

  label = lib.toUpper (lib.substring 0 1 hostname) + lib.substring 1 (-1) hostname;

  syncSnapshot = ''
    if [ ! -f ${cfg.sshKeyPath} ]; then
      printf >&2 'Missing Vaultwarden mirror key at %s\n' '${cfg.sshKeyPath}'
      exit 1
    fi

    chmod 0600 ${cfg.sshKeyPath}

    rm -rf ${localIncoming}
    mkdir -p ${localIncoming}

    if ${pkgs.rsync}/bin/rsync -a --delete \
      --chown=vaultwarden:vaultwarden \
      --chmod=D0700,F0600 \
      -e "${pkgs.openssh}/bin/ssh -T -i ${cfg.sshKeyPath} -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${sshKnownHosts} -o GlobalKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10" \
      ${primaryUser}@${primaryHost}:${remoteSnapshot} \
      ${localIncoming}/; then

      # A successful rsync of an *empty* snapshot (e.g. orchid mid-rotation, or
      # an uninitialised primary) would otherwise --delete the live store. The
      # export always writes db.sqlite3 via `sqlite3 .backup`, so treat its
      # absence as an empty/partial pull and keep the existing data instead.
      if [ ! -e ${localIncoming}/db.sqlite3 ]; then
        printf >&2 'Refusing to apply snapshot from %s: no db.sqlite3 (empty/partial pull); keeping existing data\n' '${primaryHost}'
      else
        mkdir -p ${localData}

        ${pkgs.rsync}/bin/rsync -a --delete \
          --chown=vaultwarden:vaultwarden \
          --chmod=D0700,F0600 \
          ${localIncoming}/ \
          ${localData}/

        ${pkgs.coreutils}/bin/chown -R vaultwarden:vaultwarden ${localData}
        ${pkgs.coreutils}/bin/chmod -R u=rwX,go= ${localData}
      fi
    else
      printf >&2 'Warning: could not reach %s, using existing local data\n' '${primaryHost}'
    fi
  '';
in {
  options.services.vaultwarden-mirror = {
    enable = lib.mkEnableOption "Vaultwarden read-only mirror of ${primaryHost}";

    sshKeyPath = lib.mkOption {
      type = lib.types.str;
      default = "${sshStateDir}/id_ed25519";
      description = ''
        Private key used to pull the snapshot from ${primaryHost}. Defaults to
        the mirror's own state directory; hosts with impermanence must point
        this at persistent storage (tempest keeps it under /persist/secrets).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/vaultwarden-mirror 0700 root root -"
      "d ${localIncoming} 0700 root root -"
      "d ${sshStateDir} 0700 root root -"
    ];

    systemd.services.vaultwarden-mirror-bootstrap = {
      description = "Pull Vaultwarden snapshot before startup";

      wants = [
        "network-online.target"
        "tailscale.service"
      ];
      after = [
        "network-online.target"
        "tailscale.service"
      ];
      before = [
        "vaultwarden.service"
        "backup-vaultwarden.service"
      ];
      wantedBy = [
        "vaultwarden.service"
        "backup-vaultwarden.service"
      ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };

      script = ''
        set -uo pipefail
        ${syncSnapshot}
      '';
    };

    systemd.services.vaultwarden-mirror-refresh = {
      description = "Refresh ${label} Vaultwarden snapshot";

      wants = [
        "network-online.target"
        "tailscale.service"
      ];
      after = [
        "network-online.target"
        "tailscale.service"
      ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };

      script = ''
        set -euo pipefail

        restart_vaultwarden=0
        if ${pkgs.systemd}/bin/systemctl --quiet is-active vaultwarden.service; then
          restart_vaultwarden=1
          ${pkgs.systemd}/bin/systemctl stop vaultwarden.service
        fi

        cleanup() {
          if [ "$restart_vaultwarden" -eq 1 ]; then
            ${pkgs.systemd}/bin/systemctl start vaultwarden.service
          fi
        }

        trap cleanup EXIT

        ${syncSnapshot}

        trap - EXIT
        cleanup
      '';
    };

    systemd.timers.vaultwarden-mirror-refresh = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "3m";
        OnUnitActiveSec = "5m";
        RandomizedDelaySec = "30s";
        Unit = "vaultwarden-mirror-refresh.service";
      };
    };
  };
}
