{ config, pkgs, ... }:

{
  systemd.services.scholarship-watcher = {
    enable = true;
    description = "Watch for scholarship updates";
    serviceConfig = {
      ExecStart =
        "/home/giovanni/scholarship-watcher/target/release/scholarship-watcher";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
