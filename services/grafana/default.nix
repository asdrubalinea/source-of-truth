{ ... }:
let
  grafana_port = 3333;
  grafana_domain = "grafana.local";
in
{
  networking.extraHosts =
    ''
      127.0.0.1 ${grafana_domain}
    '';

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
    port = 9001;

    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        port = 9002;
      };

      zfs = {
        enable = true;
        pools = [ "zroot" ];
        port = 9003;
      };
    };

    scrapeConfigs = [
      {
        job_name = "chrysalis";
        static_configs = [
          { targets = [ "127.0.0.1:9002" ]; }
          { targets = [ "127.0.0.1:9003" ]; }
        ];
      }
    ];
  };
}
