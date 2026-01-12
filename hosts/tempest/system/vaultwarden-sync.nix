{ pkgs, ... }:
let
  primaryHost = "orchid";
  primaryUser = "vwbackup";
  remoteSnapshot = "/persist/vaultwarden-export/current/";

  localData = "/persist/vaultwarden";
  localIncoming = "/persist/vaultwarden.incoming";
  sshKeyPath = "/persist/secrets/vaultwarden-backup/id_ed25519";
in
{
  users.groups.vwbackup = { };

  systemd.tmpfiles.rules = [
    "d ${localIncoming} 0700 root root -"
  ];

  systemd.services.vaultwarden-mirror-pull = {
    description = "Pull Vaultwarden export snapshot via rsync";
    unitConfig.RequiresMountsFor = [ "/persist" ];

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

      rm -rf ${localIncoming}
      mkdir -p ${localIncoming}

      ${pkgs.rsync}/bin/rsync -a --delete \
        -e "${pkgs.openssh}/bin/ssh -i ${sshKeyPath} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
        ${primaryUser}@${primaryHost}:${remoteSnapshot} \
        ${localIncoming}/

      rm -rf ${localData}.old || true
      if [ -e ${localData} ]; then
        mv ${localData} ${localData}.old
      fi
      mv ${localIncoming} ${localData}
      rm -rf ${localData}.old || true
    '';
  };

  systemd.timers.vaultwarden-mirror-pull = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3m";
      OnUnitActiveSec = "5m";
      RandomizedDelaySec = "30s";
      Unit = "vaultwarden-mirror-pull.service";
    };
  };
}
