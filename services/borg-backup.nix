{
  lib,
  pkgs,
  config,
  ...
}:

with lib;
let
  cfg = config.services.borg-backup;
  defaultExclude = [
    "**/Cache"
    "**/cache2"
    "**/node_modules"
    "**/target"
    "**/venv"
    "**/.BurpSuite"
    "**/.android"
    "**/.cache"
    "**/.cargo"
    "**/.config"
    "**/.local"
    "**/.rustup"
    "**/.venv"

    # Dont backup VMs
    "*.iso"
    "*.qcow2"
    "*.vdi"
    "*.vmdk"
  ];
in
{
  options.services.borg-backup = {
    enable = mkEnableOption "borg-backup";

    jobs = mkOption {
      description = "Borg jobs keyed by job name (becomes the archive prefix).";
      example = {
        home = {
          user = "irene";
          repo = "ssh://user@host:23/./backups/my-host-home";
          ssh_key_file = "/home/irene/.ssh/id_ed25519";
          password_file = "/persist/borg-home-backup/passphrase";
          paths = [ "/home/irene" ];
        };
      };
      default = { };
      type = types.attrsOf (types.submodule (
        { name, ... }:
        {
          options = {
            password_file = mkOption { type = types.str; };
            paths = mkOption { type = types.listOf types.path; };
            repo = mkOption { type = types.str; };
            ssh_key_file = mkOption { type = types.str; };
            user = mkOption { type = types.str; };
          };
        }
      ));
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.jobs != { };
        message = "services.borg-backup: set at least one job under `services.borg-backup.jobs`.";
      }
    ];

    services.borgbackup.jobs = mapAttrs (_jobName: jobCfg: {
      inherit (jobCfg) paths;
      inherit (jobCfg) repo;
      inherit (jobCfg) user;

      compression = "auto,zstd";
      environment.BORG_RSH = "ssh -i ${jobCfg.ssh_key_file}";
      exclude = defaultExclude;
      extraArgs = "--verbose";
      extraCreateArgs = "--stats";

      encryption = {
        mode = "repokey-blake2";
        passCommand = "cat ${jobCfg.password_file}";
      };

      startAt = "daily";
    }) cfg.jobs;
  };
}
