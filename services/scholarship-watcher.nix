{ config, pkgs, ... }:

{
  systemd.services.scholarship-watcher = {
    enable = true;
    description = "Watch for scholarship updates";
    unitConfig = {
      Type = "simple";
    };
    serviceConfig = {
      ExecStart = "/home/giovanni/scholarship-watcher/target/release/scholarship-watcher";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
