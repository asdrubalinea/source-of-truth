{pkgs, ...}: {
  environment.systemPackages = with pkgs; [zfs];

  # Enable SMART daemon
  services.smartd = {
    enable = true;

    notifications = {
      # Enable mail notifications
      mail = {
        enable = true;
        sender = "smartd@localhost";
        recipient = "smart@asdrubalini.xyz";
      };
      # Optionally enable wall notifications
      wall.enable = true;
    };

    defaults.monitored = "-a -o on -S on -T permissive";

    devices = [
      {device = "/dev/nvme0n1";}
      {device = "/dev/nvme1n1";}
      # { device = "/dev/nvme2n1"; }
    ];
  };

  boot.zfs = {
    # orchid only. tempest deliberately does NOT pin this — see the long note in
    # hosts/tempest/system/zfs.nix for why the module default (pkgs.zfs, i.e.
    # whatever nixpkgs calls stable) is the better choice. The same reasoning
    # applies here; this pin is inherited, not argued for.
    package = pkgs.zfs_unstable;
    forceImportAll = false;
  };

  boot.supportedFilesystems = ["zfs"];

  services.zfs = {
    autoScrub = {
      enable = true;
      interval = "Sun, 01:00";
    };

    # autoSnapshot.enable = true;
  };

  # Erase your darlings.
  # boot.initrd.postDeviceCommands = lib.mkAfter ''
  # zfs rollback -r zroot/local/root@blank
  # '';
}
