{ config, lib, pkgs, ... }:

{
  # Install snapper package
  environment.systemPackages = with pkgs; [
    snapper
  ];

  # Snapper configuration for automatic BTRFS snapshots
  services.snapper.configs = {
    home = {
      SUBVOLUME = "/home";
      ALLOW_USERS = [ "irene" ];
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      # Hourly snapshots
      TIMELINE_LIMIT_HOURLY = "24";
      # Daily snapshots
      TIMELINE_LIMIT_DAILY = "7";
      # Weekly snapshots
      TIMELINE_LIMIT_WEEKLY = "4";
      # Monthly snapshots
      TIMELINE_LIMIT_MONTHLY = "12";
      # Yearly snapshots
      TIMELINE_LIMIT_YEARLY = "2";
    };
    
    persist = {
      SUBVOLUME = "/persist";
      ALLOW_USERS = [ "irene" ];
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = "24";
      TIMELINE_LIMIT_DAILY = "7";
      TIMELINE_LIMIT_WEEKLY = "4";
      TIMELINE_LIMIT_MONTHLY = "6";
      TIMELINE_LIMIT_YEARLY = "1";
    };
    
    nix = {
      SUBVOLUME = "/nix";
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      # Less frequent snapshots for nix store
      TIMELINE_LIMIT_HOURLY = "6";
      TIMELINE_LIMIT_DAILY = "3";
      TIMELINE_LIMIT_WEEKLY = "2";
      TIMELINE_LIMIT_MONTHLY = "1";
      TIMELINE_LIMIT_YEARLY = "0";
    };
    
    log = {
      SUBVOLUME = "/var/log";
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = "12";
      TIMELINE_LIMIT_DAILY = "7";
      TIMELINE_LIMIT_WEEKLY = "2";
      TIMELINE_LIMIT_MONTHLY = "1";
      TIMELINE_LIMIT_YEARLY = "0";
    };
  };

  # Enable snapper timers
  systemd.timers."snapper-timeline" = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "hourly";
  };

  systemd.timers."snapper-cleanup" = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "daily";
  };

  # Ensure snapper directories are persisted
  environment.persistence."/persist" = {
    directories = [
      "/etc/snapper"
      "/var/lib/snapper"
      "/.snapshots"
    ];
  };
}
