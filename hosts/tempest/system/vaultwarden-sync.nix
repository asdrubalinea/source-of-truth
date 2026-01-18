{ pkgs, ... }:
let
  primaryHost = "orchid";
  primaryUser = "vwbackup";
  remoteSnapshot = "/persist/vaultwarden-export/current/";

  localData = "/persist/vaultwarden";
  localIncoming = "/persist/vaultwarden.incoming";
  sshStateDir = "/persist/vaultwarden-mirror/ssh";
  sshKnownHosts = "${sshStateDir}/known_hosts";
  sshKeyPath = "/persist/secrets/vaultwarden-backup/id_ed25519";
in
{
  users.groups.vwbackup = { };

  systemd.services.vaultwarden-fix-permissions = {
    description = "Fix Vaultwarden data permissions";
    unitConfig.RequiresMountsFor = [ "/persist" ];

    requiredBy = [
      "vaultwarden.service"
      "backup-vaultwarden.service"
    ];
    before = [
      "vaultwarden.service"
      "backup-vaultwarden.service"
    ];

    serviceConfig.Type = "oneshot";
    path = [ pkgs.coreutils ];
    script = ''
      set -euo pipefail

      if [ -d ${localData} ]; then
        chown -R vaultwarden:vaultwarden ${localData}
        chmod -R u=rwX,go= ${localData}
      fi
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${localIncoming} 0700 root root -"
    "d ${sshStateDir} 0700 root root -"
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
        --chown=vaultwarden:vaultwarden \
        --chmod=D0700,F0600 \
        -e "${pkgs.openssh}/bin/ssh -T -i ${sshKeyPath} -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${sshKnownHosts} -o GlobalKnownHostsFile=/dev/null -o LogLevel=ERROR" \
        ${primaryUser}@${primaryHost}:${remoteSnapshot} \
        ${localIncoming}/

      rm -rf ${localData}.old || true
      if [ -e ${localData} ]; then
        mv ${localData} ${localData}.old
      fi
      mv ${localIncoming} ${localData}
      ${pkgs.coreutils}/bin/chown -R vaultwarden:vaultwarden ${localData}
      ${pkgs.coreutils}/bin/chmod -R u=rwX,go= ${localData}
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
