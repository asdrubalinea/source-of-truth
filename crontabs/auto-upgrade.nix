{ config, pkgs, ... }:

{
  services.cron = {
    enable = true;
    # Execute every day at midnight
    systemCronJobs = [ "0 0 * * * system-upgrade >/dev/null 2>&1" ];
  };
}
