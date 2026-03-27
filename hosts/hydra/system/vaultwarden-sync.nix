{ pkgs, ... }:
let
  primaryHost = "orchid";
  primaryUser = "vwbackup";
  remoteSnapshot = "/persist/vaultwarden-export/current/";

  localData = "/var/lib/vaultwarden";
  localIncoming = "/var/lib/vaultwarden-mirror/incoming";
  sshStateDir = "/var/lib/vaultwarden-mirror/ssh";
  sshKnownHosts = "${sshStateDir}/known_hosts";
  sshKeyPath = "${sshStateDir}/id_ed25519";

  syncSnapshot = ''
    if [ ! -f ${sshKeyPath} ]; then
      printf >&2 'Missing Vaultwarden mirror key at %s\n' '${sshKeyPath}'
      exit 1
    fi

    chmod 0600 ${sshKeyPath}

    rm -rf ${localIncoming}
    mkdir -p ${localIncoming}

    if ${pkgs.rsync}/bin/rsync -a --delete \
      --chown=vaultwarden:vaultwarden \
      --chmod=D0700,F0600 \
      -e "${pkgs.openssh}/bin/ssh -T -i ${sshKeyPath} -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${sshKnownHosts} -o GlobalKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10" \
      ${primaryUser}@${primaryHost}:${remoteSnapshot} \
      ${localIncoming}/; then

      mkdir -p ${localData}

      ${pkgs.rsync}/bin/rsync -a --delete \
        --chown=vaultwarden:vaultwarden \
        --chmod=D0700,F0600 \
        ${localIncoming}/ \
        ${localData}/

      ${pkgs.coreutils}/bin/chown -R vaultwarden:vaultwarden ${localData}
      ${pkgs.coreutils}/bin/chmod -R u=rwX,go= ${localData}
    else
      printf >&2 'Warning: could not reach %s, using existing local data\n' '${primaryHost}'
    fi
  '';
in
{
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
    description = "Refresh Hydra Vaultwarden snapshot";

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
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3m";
      OnUnitActiveSec = "5m";
      RandomizedDelaySec = "30s";
      Unit = "vaultwarden-mirror-refresh.service";
    };
  };
}
