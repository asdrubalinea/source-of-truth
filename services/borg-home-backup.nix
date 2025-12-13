{
  lib,
  pkgs,
  config,
  ...
}:

with lib;
let
  cfg = config.services.borg-home-backup;
  wait-ac = (pkgs.callPackage ../scripts/wait-ac.nix { }).wait-ac;
in
{
  options.services.borg-home-backup = {
    enable = mkEnableOption "borg-home-backup";

    name = mkOption { type = types.str; };
    user = mkOption { type = types.str; };
    repo = mkOption { type = types.str; };
    ssh_key_file = mkOption { type = types.str; };
    password_file = mkOption { type = types.str; };
    paths = mkOption { type = types.listOf (types.path); };
  };

  config = mkIf cfg.enable {
    services.borgbackup.jobs.${cfg.name} = {
      inherit (cfg) repo;
      inherit (cfg) paths;
      inherit (cfg) user;

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
        "**/.android"
        "**/.BurpSuite"

        # Dont backup VMs
        "*.iso"
        "*.qcow2"
        "*.vdi"
        "*.vmdk"
      ];

      encryption = {
        mode = "repokey-blake2";
        passCommand = "cat ${cfg.password_file}";
      };

      environment.BORG_RSH = "ssh -i ${cfg.ssh_key_file}";
      compression = "auto,zstd";
      startAt = "daily";
      extraCreateArgs = "--stats";
      extraArgs = "--verbose";
    };
  };
}
