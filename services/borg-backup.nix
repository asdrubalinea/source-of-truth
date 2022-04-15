{ lib, pkgs, config, ... }:

with lib;
let
  cfg = config.services.borg-backup;
  wait-ac = (pkgs.callPackage ../scripts/wait-ac.nix { }).wait-ac;

in {
  options.services.borg-backup = {
    enable = mkEnableOption "borg-backup";

    name = mkOption { type = types.str; };
    repo = mkOption { type = types.str; };
    ssh_key_file = mkOption { type = types.str; };
    password_file = mkOption { type = types.str; };
  };

  config = mkIf cfg.enable {
    services.borgbackup.jobs.${cfg.name} = {
      inherit (cfg) repo;

      exclude = [
        "**/node_modules"
        "**/cache2"
        "**/Cache"
        "**/venv"
        "**/.venv"
        "**/target"

        "**/.rustup"
        "**/.cargo"
        "**/.config"
        "**/.cache"
        "**/.local"

        # Dont backup VMs
        "*.iso"
        "*.qcow2"
        "*.vdi"
        "*.vmdk"

        "*.deb"
      ];

      encryption = {
        mode = "repokey-blake2";
        passCommand = "cat ${cfg.password_file}";
      };

      environment.BORG_RSH =
        "ssh -i ${cfg.ssh_key_file} -o StrictHostKeyChecking=no";
      compression = "zstd,1";
      startAt = "weekly";
      extraCreateArgs = "--stats";
      extraArgs = "--verbose";

      preHook = ''
        ${wait-ac}/bin/wait-ac

        if [[ $(${pkgs.zfs}/bin/zfs list | grep data0/safe@borg) ]]; then
          /run/wrappers/bin/umount /tmp/borg/home || true
          /run/wrappers/bin/umount /tmp/borg/persist || true
          ${pkgs.zfs}/bin/zfs destroy -r data0/safe@borg
        fi

        ${pkgs.zfs}/bin/zfs snapshot -r data0/safe@borg

        mkdir -p /tmp/borg/{home,persist}
        /run/wrappers/bin/mount -t zfs data0/safe/home@borg /tmp/borg/home
        /run/wrappers/bin/mount -t zfs data0/safe/persist@borg /tmp/borg/persist
      '';

      paths = [ "/tmp/borg/" ];

      postHook = ''
        /run/wrappers/bin/umount /tmp/borg/home
        /run/wrappers/bin/umount /tmp/borg/persist
        ${pkgs.zfs}/bin/zfs destroy -r data0/safe@borg
      '';
    };
  };
}
