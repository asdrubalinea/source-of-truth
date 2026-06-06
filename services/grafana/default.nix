{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.monitoring;

  # node-exporter has no inotify collector, so we publish the counts ourselves
  # via the textfile collector: this directory is what the exporter reads, and
  # the collector below writes an inotify.prom into it.
  textfileDir = "/var/lib/node-exporter-textfile";

  inotifyExporter = pkgs.writeShellScriptBin "node-inotify-textfile" ''
    set -euo pipefail
    export PATH=${makeBinPath [ pkgs.coreutils pkgs.gnugrep pkgs.findutils ]}

    dir=${textfileDir}
    tmp=$(mktemp "$dir/inotify.prom.XXXXXX")
    chmod 0644 "$tmp" # mktemp makes 0600; node-exporter runs as another user

    # Total watches = every "inotify " line across all processes' fdinfo. /proc
    # entries vanish mid-scan, so stream through cat | grep (which skips a
    # vanished file) rather than handing the glob to awk, which dies fatally on
    # the first unreadable file.
    watches=$(cat /proc/[0-9]*/fdinfo/* 2>/dev/null | grep -c '^inotify ' || true)
    instances=$(find /proc/[0-9]*/fd -lname 'anon_inode:inotify' 2>/dev/null | wc -l || true)
    max_watches=$(cat /proc/sys/fs/inotify/max_user_watches)
    max_instances=$(cat /proc/sys/fs/inotify/max_user_instances)

    {
      echo "# HELP node_inotify_watches Inotify watches in use across all processes."
      echo "# TYPE node_inotify_watches gauge"
      echo "node_inotify_watches $watches"
      echo "# HELP node_inotify_instances Inotify instances (fds) in use across all processes."
      echo "# TYPE node_inotify_instances gauge"
      echo "node_inotify_instances $instances"
      echo "# HELP node_inotify_max_user_watches fs.inotify.max_user_watches sysctl (per-uid limit)."
      echo "# TYPE node_inotify_max_user_watches gauge"
      echo "node_inotify_max_user_watches $max_watches"
      echo "# HELP node_inotify_max_user_instances fs.inotify.max_user_instances sysctl (per-uid limit)."
      echo "# TYPE node_inotify_max_user_instances gauge"
      echo "node_inotify_max_user_instances $max_instances"
    } > "$tmp"

    # Atomic publish; the temp name lacks a trailing .prom so the collector
    # never reads a half-written file.
    mv "$tmp" "$dir/inotify.prom"
  '';
in
{
  options.services.monitoring = {
    enable = mkEnableOption "monitoring stack (Grafana + Prometheus)";

    powerEfficient = mkOption {
      type = types.bool;
      default = false;
      description = "Enable power-efficient settings for laptop usage";
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
          http_port = 3333;
        };

        # NixOS 26.05 dropped Grafana's built-in default secret_key. This key
        # only encrypts secrets stored in Grafana's own DB (datasource creds,
        # alerting contact points) — this instance configures none, so the
        # historical default is hard-coded rather than file-provisioned.
        security.secret_key = "SW2YcwTIb9zpOOhoPsMm";

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

      # Provision the Prometheus datasource. Without this Grafana has no
      # datasource at all and every panel renders "No data". Always
      # provisioned, independent of powerEfficient. The fixed uid lets the
      # bundled dashboards reference it deterministically.
      provision = {
        enable = true;
        datasources.settings.datasources = [{
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://localhost:${toString config.services.prometheus.port}";
          uid = "prometheus";
          isDefault = true;
        }];

        # Bundled dashboards
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

      scrapeConfigs = [{
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:9902" ];
        }];
        scrape_interval = if cfg.powerEfficient then "120s" else null;
      }];

      # Node exporter with optimized collectors
      exporters.node = {
        enable = true;
        port = 9902;
        enabledCollectors =
          # wifi (signal strength) is off by default; enable it in both modes.
          [ "wifi" ]
          ++ (if cfg.powerEfficient then [
            # Essential collectors only
            "cpu"
            "cpufreq"
            "loadavg"
            "meminfo"
            "filesystem"
            "diskstats"
            "netstat"
            "netclass"
            "powersupplyclass" # Battery monitoring
            "thermal_zone" # Temperature monitoring
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
          ]);

        extraFlags = [
          "--collector.cpu.info.bugs-include=^(meltdown|spectre|tsx_async_abort)$"
          "--collector.textfile.directory=${textfileDir}"
        ] ++ optional cfg.powerEfficient "--collector.cpu.info";
      };
    };

    # Hardware sensors exporter (optional)
    # Note: lmsensors exporter is already configured elsewhere in the system

    # Powertop exporter (optional, with reduced frequency)
    # Note: powertop exporter is configured elsewhere in the system
    # The prometheus-powertop-exporter package is not available in nixpkgs

    # Ensure services restart on failure
    systemd.services = {
      grafana.serviceConfig = {
        Restart = "on-failure";
        RestartSec = "10s";
        # Reduce resource usage
        CPUQuota = mkIf cfg.powerEfficient "20%";
        MemoryMax = mkIf cfg.powerEfficient "512M";
      };

      prometheus.serviceConfig = {
        RestartSec = "10s";
        # Reduce resource usage
        CPUQuota = mkIf cfg.powerEfficient "10%";
        MemoryMax = mkIf cfg.powerEfficient "256M";
      };

      # Publish inotify watch counts for the textfile collector. Runs as root
      # (the default) because counting watches means reading every process's
      # /proc/<pid>/fdinfo, which is root-only for other users' processes.
      node-inotify-textfile = {
        description = "Collect inotify watch counts for the node-exporter textfile collector";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${inotifyExporter}/bin/node-inotify-textfile";
        };
      };
    };

    systemd.timers.node-inotify-textfile = {
      description = "Periodically collect inotify watch counts";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "1min";
      };
    };

    # Directory the node-exporter textfile collector reads. World-readable so
    # the exporter (a different user, read-only rootfs) can read the .prom.
    systemd.tmpfiles.rules = [
      "d ${textfileDir} 0755 root root -"
    ];
  };
}
