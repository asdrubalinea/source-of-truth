{ pkgs, ... }:
let
  vwData = "/persist/vaultwarden";
  exportRoot = "/persist/vaultwarden-export";
  exportCurrent = "${exportRoot}/current";
  exportNext = "${exportRoot}/next";
in
{
  users.groups.vwbackup = { };

  users.users.vwbackup = {
    isSystemUser = true;
    group = "vwbackup";
    home = "/var/lib/vwbackup";
    createHome = true;

    # Put the public key (optionally with restrictions) in this file, e.g.:
    # command="/etc/vwbackup/rsync-snapshot",restrict ssh-ed25519 AAAA...
    openssh.authorizedKeys.keyFiles = [
      "/persist/secrets/vaultwarden-backup/authorized_keys"
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${exportRoot} 0750 root vwbackup -"
    "d ${exportCurrent} 0750 root vwbackup -"
    "d ${exportNext} 0750 root vwbackup -"
  ];

  environment.etc."vwbackup/rsync-snapshot" = {
    mode = "0555";
    text = ''
      #!/bin/sh
      exec ${pkgs.rsync}/bin/rsync --server --sender -logDtpre.iLsfxCIvu . ${exportCurrent}/
    '';
  };

  systemd.services.vaultwarden-export-snapshot = {
    description = "Create consistent Vaultwarden export snapshot for rsync pulls";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "vwbackup";
      UMask = "0027";
    };

    script = ''
      set -euo pipefail

      rm -rf ${exportNext}
      mkdir -p ${exportNext}

      # Copy everything except the live SQLite files; we'll generate db.sqlite3 via `.backup`.
      if [ -d ${vwData} ]; then
        ${pkgs.rsync}/bin/rsync -a --delete \
          --exclude='db.sqlite3*' \
          --chown=root:vwbackup \
          --chmod=D0750,F0640 \
          ${vwData}/ \
          ${exportNext}/
      fi

      if [ -e ${vwData}/db.sqlite3 ]; then
        ${pkgs.sqlite}/bin/sqlite3 ${vwData}/db.sqlite3 \
          ".backup '${exportNext}/db.sqlite3'"
        chmod 0640 ${exportNext}/db.sqlite3
        chown root:vwbackup ${exportNext}/db.sqlite3
      fi

      rm -rf ${exportCurrent}.old || true
      if [ -d ${exportCurrent} ]; then
        mv ${exportCurrent} ${exportCurrent}.old
      fi
      mv ${exportNext} ${exportCurrent}
      rm -rf ${exportCurrent}.old || true
    '';
  };

  systemd.timers.vaultwarden-export-snapshot = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "5m";
      RandomizedDelaySec = "30s";
      Unit = "vaultwarden-export-snapshot.service";
    };
  };
}

