{ config, pkgs, ... }:

{
  systemd.services.website-tracker = {
    enable = true;
    description = "Track website response time";
    serviceConfig = {
      ExecStart = "/home/giovanni/website-tracker/target/release/website-response-time-tracker";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
