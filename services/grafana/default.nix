{ ... }:
let
  grafana_port = 3333;
  grafana_domain = "grafana.asdrubalini.com";
in
{
  services.grafana = {
    enable = true;

    settings = {
      server = {
        domain = grafana_domain;
        http_addr = "127.0.0.1";
        http_port = grafana_port;
      };
    };
  };

  services.prometheus = {
    enable = true;
    port = 9901;
    globalConfig.scrape_interval = "5s";

    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        port = 9902;
      };

      zfs = {
        enable = true;
        pools = [ "zroot" ];
        port = 9903;
      };
    };

    scrapeConfigs = [
      {
        job_name = "chrysalis";
        static_configs = [
          { targets = [ "127.0.0.1:9902" ]; }
          { targets = [ "127.0.0.1:9903" ]; }
        ];
      }
    ];
  };
}
