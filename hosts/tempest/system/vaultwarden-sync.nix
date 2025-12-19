{
  lib,
  pkgs,
  ...
}:
let
  sourceHost = "orchid";
  sourcePath = "/persist/vaultwarden/";

  destinationPath = "/persist/vaultwarden/";

  sshIdentityFile = "/home/irene/.ssh/id_ed25519";
  sshKnownHostsFile = "/home/irene/.ssh/known_hosts";

  syncScript = pkgs.writeShellScript "vaultwarden-sync" ''
    set -euo pipefail

    INSTALL=${lib.escapeShellArg "${pkgs.coreutils}/bin/install"}
    DIRNAME=${lib.escapeShellArg "${pkgs.coreutils}/bin/dirname"}
    TOUCH=${lib.escapeShellArg "${pkgs.coreutils}/bin/touch"}
    SSH=${lib.escapeShellArg "${pkgs.openssh}/bin/ssh"}

    SOURCE_HOST=${lib.escapeShellArg sourceHost}
    SOURCE_PATH=${lib.escapeShellArg sourcePath}
    DESTINATION_PATH=${lib.escapeShellArg destinationPath}
    SSH_IDENTITY_FILE=${lib.escapeShellArg sshIdentityFile}
    SSH_KNOWN_HOSTS_FILE=${lib.escapeShellArg sshKnownHostsFile}

    if [[ ! -r "$SSH_IDENTITY_FILE" ]]; then
      echo "vaultwarden-sync: missing SSH key: $SSH_IDENTITY_FILE" >&2
      exit 2
    fi

    if [[ "$DESTINATION_PATH" != /persist/* ]]; then
      echo "vaultwarden-sync: refusing to sync outside /persist: $DESTINATION_PATH" >&2
      exit 2
    fi

    "$INSTALL" -d -m 0700 -o root -g root "$DESTINATION_PATH"
    if [[ "$SSH_KNOWN_HOSTS_FILE" == /persist/* || "$SSH_KNOWN_HOSTS_FILE" == /root/* ]]; then
      "$INSTALL" -d -m 0700 -o root -g root "$("$DIRNAME" "$SSH_KNOWN_HOSTS_FILE")"
      "$TOUCH" "$SSH_KNOWN_HOSTS_FILE"
    fi

    ${pkgs.rsync}/bin/rsync \
      --archive \
      --delete-delay \
      --numeric-ids \
      --partial \
      --stats \
      -e "$SSH -i $SSH_IDENTITY_FILE -o BatchMode=yes -o ConnectTimeout=30 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$SSH_KNOWN_HOSTS_FILE" \
      "root@$SOURCE_HOST:$SOURCE_PATH" \
      "$DESTINATION_PATH"
  '';
in
{
  systemd.services.vaultwarden-sync = {
    description = "Sync /persist/vaultwarden from orchid to tempest";

    after = [
      "network-online.target"
      "tailscaled.service"
    ];
    wants = [ "network-online.target" ];

    unitConfig = {
      RequiresMountsFor = [ "/persist" ];
    };

    serviceConfig = {
      Type = "oneshot";
      ExecStart = syncScript;
      UMask = "0077";
      User = "root";
    };
  };

  systemd.timers.vaultwarden-sync = {
    description = "Daily sync of /persist/vaultwarden from orchid";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnBootSec = "10m";
      OnUnitActiveSec = "24h";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };
}
