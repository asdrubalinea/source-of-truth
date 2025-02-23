{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [ zfs ];

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
      { device = "/dev/nvme0n1"; }
      { device = "/dev/nvme1n1"; }
      { device = "/dev/nvme2n1"; }
    ];
  };

  boot.zfs = {
    package = pkgs.zfs_unstable;
    forceImportAll = false;
  };

  boot.supportedFilesystems = [ "zfs" ];

  services.zfs = {
    autoScrub = {
      enable = true;
      interval = "Sun, 01:00";
    };

    autoSnapshot.enable = true;
  };

  # Erase your darlings.
  # boot.initrd.postDeviceCommands = lib.mkAfter ''
  # zfs rollback -r zroot/local/root@blank
  # '';
}
