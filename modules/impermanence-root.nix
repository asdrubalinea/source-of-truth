{
  lib,
  config,
  ...
}: let
  persistedFiles =
    map
    (
      f:
        if builtins.isString f
        then f
        else f.file
    )
    config.environment.persistence."/persist".files;
in {
  # The tmpfs-root half of impermanence, shared by tempest and orchid: the root
  # filesystem is RAM and is discarded on every boot, so anything that must
  # survive is either on a ZFS dataset (disks/<host>.nix, which also emits
  # fileSystems."/") or bind-mounted from /persist.
  #
  # What lives here is the machine-identity core plus the two mechanics that are
  # easy to forget and expensive to notice missing (the build-dir redirect and the
  # soft-reboot fixup). Service state stays in each host's system/persistence.nix,
  # next to the decision to run the service at all.

  fileSystems = {
    # device + fsType come from disko's rpool/persist datasets. Both must be
    # mounted before impermanence binds /home/irene from /persist/home/irene.
    "/persist".neededForBoot = true;
    "/persist/home".neededForBoot = true;
  };

  # Nix builds must not happen in RAM. /tmp is part of the tmpfs root and the
  # daemon builds there by default, so one big closure can fill the root and take
  # the machine with it. /nix/tmp instead: it is on the pool, it is the same
  # dataset as the store (so the build output moves into place instead of being
  # copied across datasets), and rpool/nix is not snapshotted — unlike /persist,
  # where hourly sanoid snapshots would pin every build's scratch files. Leftovers
  # from crashed builds age out after 7 days.
  nix.envVars.TMPDIR = "/nix/tmp";
  systemd.tmpfiles.rules = ["d /nix/tmp 1777 root root 7d"];

  environment.persistence."/persist" = {
    enable = true;
    hideMounts = true;

    directories = [
      # System logs
      "/var/log"

      # System state
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/coredump"

      # Own the home explicitly. As a bare string, impermanence creates the
      # /persist source dir as root:root and never enforces ownership — so on a
      # FRESH dataset (a clean install, or the tempest-vm image) /home/irene
      # comes up root-owned, the user can't write their own home, and the
      # first-boot home-manager activation fails ("could not find suitable
      # profile directory"). It only ever "worked" on tempest because the dir was
      # fixed by hand once and then persisted. Setting user/group/mode makes
      # impermanence create AND enforce irene:users 0700, so first boot is
      # correct everywhere.
      {
        directory = "/home/irene";
        user = "irene";
        group = "users";
        mode = "0700";
      }
    ];

    files = [
      "/etc/machine-id"

      # SSH host keys. Regenerated — and therefore changed — on every boot
      # without this, which breaks every known_hosts entry pointing at the host,
      # including the vaultwarden mirrors' accept-new pull.
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };

  # After `systemctl soft-reboot` the tmpfs root persists but impermanence's
  # bind mounts are torn down; systemd then regenerates /etc/machine-id and the
  # SSH host keys directly on tmpfs before activation runs, which trips
  # mount-file's "A file already exists" guard. Drop any persisted file that
  # isn't currently bind-mounted so persist-files can re-establish the mount.
  system.activationScripts.persist-files.text = lib.mkBefore ''
    for _imperm_f in ${lib.escapeShellArgs persistedFiles}; do
      if ! findmnt -- "$_imperm_f" >/dev/null 2>&1; then
        rm -f -- "$_imperm_f"
      fi
    done
  '';
}
