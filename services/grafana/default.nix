{ config, lib, ... }:

with lib;

let
  cfg = config.services.monitoring;
in
{
  options.services.monitoring = {
    enable = mkEnableOption "monitoring stack (Grafana + Prometheus)";

    powerEfficient = mkOption {
      type = types.bool;
      default = false;
      description = "Enable power-efficient settings for laptop usage";
    };

    enableHardwareSensors = mkOption {
      type = types.bool;
      default = false;
      description = "Enable hardware sensor monitoring (lm_sensors)";
    };

    enablePowertopExporter = mkOption {
      type = types.bool;
      default = false;
      description = "Enable powertop exporter for power consumption metrics";
    };

    prometheusRetentionDays = mkOption {
      type = types.int;
      default = 7;
      description = "Number of days to retain Prometheus data";
    };

    scrapeInterval = mkOption {
      type = types.str;
      default = "15s";
      description = "Prometheus scrape interval";
    };
  };

  config = mkIf cfg.enable {
    # Grafana configuration
    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = 3000;
        };

        # Power-efficient settings
        analytics = mkIf cfg.powerEfficient {
          reporting_enabled = false;
          check_for_updates = false;
          check_for_plugin_updates = false;
        };

        # Reduce database writes
        database = mkIf cfg.powerEfficient {
          wal = false;
          cache_mode = "shared";
        };

        # Disable unused features for power efficiency
        alerting = mkIf cfg.powerEfficient {
          enabled = false;
        };

        # Reduce log verbosity
        log = mkIf cfg.powerEfficient {
          level = "warn";
        };
      };

      # Default dashboards optimized for power efficiency
      provision = mkIf cfg.powerEfficient {
        dashboards.settings.providers = [{
          name = "default";
          options.path = ./dashboards;
        }];
      };
    };

    # Prometheus configuration
    services.prometheus = {
      enable = true;
      port = 9901;

      # Power-efficient retention
      retentionTime = "${toString cfg.prometheusRetentionDays}d";

      # Global configuration
      globalConfig = {
        scrape_interval = if cfg.powerEfficient then "60s" else cfg.scrapeInterval;
        evaluation_interval = if cfg.powerEfficient then "60s" else "15s";
      };

      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [{
            targets = [ "localhost:9902" ];
          }];
          # Longer scrape interval for power efficiency
          scrape_interval = if cfg.powerEfficient then "120s" else null;
        }
      ] ++ optional (!cfg.powerEfficient) {
        job_name = "systemd";
        static_configs = [{
          targets = [ "localhost:9903" ];
        }];
      };
    };

    # Node exporter with optimized collectors
    services.prometheus.exporters.node = {
      enable = true;
      port = 9902;
      enabledCollectors = if cfg.powerEfficient then [
        # Essential collectors only
        "cpu"
        "cpufreq"
        "loadavg"
        "meminfo"
        "filesystem"
        "diskstats"
        "netstat"
        "netclass"
        "powersupplyclass"  # Battery monitoring
        "thermal_zone"      # Temperature monitoring
        "time"
        "uname"
        "vmstat"
      ] else [
        # Full set of collectors
        "cpu"
        "cpufreq"
        "diskstats"
        "filesystem"
        "hwmon"
        "interrupts"
        "loadavg"
        "meminfo"
        "netclass"
        "netstat"
        "powersupplyclass"
        "pressure"
        "processes"
        "rapl"
        "schedstat"
        "softirqs"
        "stat"
        "systemd"
        "textfile"
        "thermal_zone"
        "time"
        "uname"
        "vmstat"
      ];

      extraFlags = [
        "--collector.cpu.info.bugs-include=^(meltdown|spectre|tsx_async_abort)$"
      ] ++ optional cfg.powerEfficient "--collector.cpu.info";
    };

    # Systemd exporter (disabled in power-efficient mode)
    services.prometheus.exporters.systemd = mkIf (!cfg.powerEfficient) {
      enable = true;
      port = 9903;
    };

    # Hardware sensors exporter (optional)
    # Note: lmsensors exporter is already configured elsewhere in the system

    # Powertop exporter (optional, with reduced frequency)
    # Note: powertop exporter is configured elsewhere in the system
    # The prometheus-powertop-exporter package is not available in nixpkgs

    # Ensure services restart on failure
    systemd.services.grafana.serviceConfig = {
      Restart = "on-failure";
      RestartSec = "10s";
      # Reduce resource usage
      CPUQuota = mkIf cfg.powerEfficient "20%";
      MemoryMax = mkIf cfg.powerEfficient "512M";
    };

    systemd.services.prometheus.serviceConfig = {
      RestartSec = "10s";
      # Reduce resource usage
      CPUQuota = mkIf cfg.powerEfficient "10%";
      MemoryMax = mkIf cfg.powerEfficient "256M";
    };
  };
}
