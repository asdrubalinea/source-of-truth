{ config, lib, pkgs, ... }:
let
  cfg = config.services.monitoring;

  ports = {
    grafana = 3333;
    prometheus = 9901;
    node = 9902;
    zfs = 9903;
    lmsensors = 9904;
    smartctl = 9905;
    amdgpu = 9906;
    systemd = 9907;
  };

  scrapeInterval = if cfg.powerEfficient then "60s" else "30s";
in
{
  options.services.monitoring = {
    enable = lib.mkEnableOption "Grafana monitoring stack";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "grafana.asdrubalini.com";
      description = "Domain for Grafana web interface";
    };

    powerEfficient = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable power-efficient settings (longer scrape intervals)";
    };

    enableZfs = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable ZFS monitoring";
    };

    zfsPools = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "zroot" ];
      description = "ZFS pools to monitor";
    };

    enableAmdGpu = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable AMD GPU monitoring";
    };

    enableHardwareSensors = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable hardware sensor monitoring (temperatures, voltages, fans)";
    };

    enableSmartMonitoring = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable SMART disk monitoring";
    };

    enablePowertopExporter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable powertop-based process power monitoring";
    };

    textfileCollectorPath = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/prometheus-node-exporter/textfile-collector";
      description = "Path for node exporter textfile collector";
    };
  };

  config = lib.mkIf cfg.enable {
    # Install required packages
    environment.systemPackages = with pkgs; [
      # Hardware monitoring tools
      lm_sensors
      powertop
      s-tui # Terminal UI for monitoring CPU temp and frequency
      moreutils # For sponge utility used in powertop script
    ] ++ lib.optionals cfg.enableAmdGpu [
      radeontop # AMD GPU monitoring
    ];

    # Enable lm_sensors service for hardware monitoring
    hardware.sensor.iio.enable = true;

    # Grafana configuration
    services.grafana = {
      enable = true;

      settings = {
        server = {
          domain = cfg.domain;
          http_addr = "127.0.0.1";
          http_port = ports.grafana;
        };

        # Power-efficient settings for laptops
        analytics.reporting_enabled = false;

        # Reduce database writes on laptops
        database = lib.mkIf cfg.powerEfficient {
          wal = true;
          max_idle_conns = 2;
          max_open_conns = 10;
        };
      };

      # Pre-configure data sources
      provision = {
        enable = true;
        datasources.settings.datasources = [{
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:${toString ports.prometheus}";
          isDefault = true;
        }];
      };
    };

    # Prometheus configuration
    services.prometheus = {
      enable = true;
      port = ports.prometheus;

      globalConfig = {
        scrape_interval = scrapeInterval;
        evaluation_interval = scrapeInterval;
      };

      exporters = {
        # Node exporter with extensive collectors
        node = {
          enable = true;
          port = ports.node;
          enabledCollectors = [
            "systemd"
            "thermal_zone" # CPU/GPU temperatures
            "powersupplyclass" # Battery and AC adapter info
            "pressure" # PSI (Pressure Stall Information)
            "processes" # Process statistics
            "meminfo" # Detailed memory statistics
            "loadavg" # System load
            "filesystem" # Disk usage
            "diskstats" # Disk I/O statistics
            "netstat" # Network statistics
            "cpu" # CPU usage
            "cpufreq" # CPU frequency scaling
            "hwmon" # Hardware monitoring (temps, fans, voltages)
            "rapl" # Running Average Power Limit (Intel/AMD power consumption)
            "drm" # GPU memory and state info
            "interrupts" # IRQ statistics
            "softirqs" # Soft IRQ statistics
            "netclass" # Network interface info
            "schedstat" # CPU scheduler statistics
            "stat" # Various kernel statistics
            "time" # System time
            "uname" # System info
            "vmstat" # Virtual memory statistics
          ] ++ lib.optionals cfg.enablePowertopExporter [
            "textfile" # For powertop metrics
          ];

          extraFlags = lib.optionals cfg.powerEfficient [
            # Reduce collection frequency for power efficiency
            "--collector.cpu.info.bugs-include=^(meltdown|spectre|tsx_async_abort)$"
          ] ++ lib.optionals cfg.enablePowertopExporter [
            "--collector.textfile.directory=${cfg.textfileCollectorPath}"
          ];
        };

        # ZFS exporter (conditional)
        zfs = lib.mkIf cfg.enableZfs {
          enable = true;
          pools = cfg.zfsPools;
          port = ports.zfs;
        };

        # SMART monitoring for disk health (conditional)
        smartctl = lib.mkIf cfg.enableSmartMonitoring {
          enable = true;
          port = ports.smartctl;
          devices = [ "/dev/nvme0n1" ]; # Framework laptop NVMe
        };

        # Systemd exporter for service monitoring
        systemd = {
          enable = true;
          port = ports.systemd;
          extraFlags = [
            "--systemd.collector.unit-include=^(grafana|prometheus|NetworkManager|bluetooth|thermald|power-profiles-daemon)\.service$"
          ];
        };
      };


      # Scrape configurations
      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [{
            targets = [ "127.0.0.1:${toString ports.node}" ];
            labels = {
              host = config.networking.hostName;
            };
          }];
        }
        {
          job_name = "systemd";
          static_configs = [{
            targets = [ "127.0.0.1:${toString ports.systemd}" ];
            labels = {
              host = config.networking.hostName;
            };
          }];
        }
      ] ++ lib.optionals cfg.enableZfs [{
        job_name = "zfs";
        static_configs = [{
          targets = [ "127.0.0.1:${toString ports.zfs}" ];
          labels = {
            host = config.networking.hostName;
          };
        }];
      }] ++ lib.optionals cfg.enableSmartMonitoring [{
        job_name = "smartctl";
        static_configs = [{
          targets = [ "127.0.0.1:${toString ports.smartctl}" ];
          labels = {
            host = config.networking.hostName;
          };
        }];
      }] ++ lib.optionals cfg.enableAmdGpu [{
        job_name = "amdgpu";
        static_configs = [{
          targets = [ "127.0.0.1:${toString ports.amdgpu}" ];
          labels = {
            host = config.networking.hostName;
          };
        }];
      }] ++ lib.optionals cfg.enableHardwareSensors [{
        job_name = "lmsensors";
        static_configs = [{
          targets = [ "127.0.0.1:${toString ports.lmsensors}" ];
          labels = {
            host = config.networking.hostName;
          };
        }];
      }];

      # Retention settings (shorter for laptops to save disk space)
      retentionTime = if cfg.powerEfficient then "7d" else "30d";
    };

    # Create a custom lm_sensors exporter service
    systemd.services.prometheus-lmsensors-exporter = lib.mkIf cfg.enableHardwareSensors {
      description = "Prometheus lm_sensors exporter";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.writeShellScript "lmsensors-exporter" ''
          #!/bin/sh
          while true; do
            echo "# lm_sensors metrics"
            ${pkgs.lm_sensors}/bin/sensors -u | ${pkgs.gawk}/bin/awk '
              /^[a-zA-Z]/ { chip=$1; gsub(/:$/, "", chip) }
              /_input:/ {
                sensor=substr($1, 1, index($1, "_input:")-1)
                value=$2
                # Convert sensor names to Prometheus format
                gsub(/-/, "_", sensor)
                gsub(/-/, "_", chip)

                # Determine metric type and unit
                if (sensor ~ /^temp/) {
                  print "lmsensors_temperature_celsius{chip=\"" chip "\",sensor=\"" sensor "\"} " value
                } else if (sensor ~ /^in[0-9]/) {
                  print "lmsensors_voltage_volts{chip=\"" chip "\",sensor=\"" sensor "\"} " value
                } else if (sensor ~ /^fan/) {
                  print "lmsensors_fan_rpm{chip=\"" chip "\",sensor=\"" sensor "\"} " value
                } else if (sensor ~ /^power/) {
                  print "lmsensors_power_watts{chip=\"" chip "\",sensor=\"" sensor "\"} " value/1000000
                } else if (sensor ~ /^curr/) {
                  print "lmsensors_current_amps{chip=\"" chip "\",sensor=\"" sensor "\"} " value
                }
              }
            '
            sleep ${scrapeInterval}
          done | ${pkgs.prometheus-node-exporter}/bin/node_exporter \
            --web.listen-address=":${toString ports.lmsensors}" \
            --collector.textfile.directory=/dev/stdin \
            --collector.disable-defaults
        ''}";

        Restart = "always";
        User = "nobody";

        # Security hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };

    # Create AMD GPU exporter service
    systemd.services.prometheus-amdgpu-exporter = lib.mkIf cfg.enableAmdGpu {
      description = "Prometheus AMD GPU exporter";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [ coreutils gawk ];

      serviceConfig = {
        ExecStart = "${pkgs.writeShellScript "amdgpu-exporter" ''
          #!/bin/sh
          # Find the AMD GPU card
          card=""
          for c in /sys/class/drm/card*; do
            if [ -f "$c/device/vendor" ] && [ "$(cat $c/device/vendor)" = "0x1002" ]; then
              card="$c"
              break
            fi
          done

          if [ -z "$card" ]; then
            echo "No AMD GPU found" >&2
            exit 1
          fi

          while true; do
            echo "# AMD GPU metrics"

            # GPU temperature
            for temp in $card/device/hwmon/hwmon*/temp*_input; do
              if [ -f "$temp" ]; then
                sensor=$(basename "$temp" | sed 's/_input$//')
                value=$(cat "$temp" 2>/dev/null)
                if [ -n "$value" ]; then
                  echo "amdgpu_temperature_celsius{sensor=\"$sensor\"} $(($value / 1000))"
                fi
              fi
            done

            # GPU power consumption
            for power in $card/device/hwmon/hwmon*/power*_average; do
              if [ -f "$power" ]; then
                sensor=$(basename "$power" | sed 's/_average$//')
                value=$(cat "$power" 2>/dev/null)
                if [ -n "$value" ]; then
                  echo "amdgpu_power_watts{sensor=\"$sensor\"} $(awk "BEGIN {print $value / 1000000}")"
                fi
              fi
            done

            # GPU memory usage
            if [ -f "$card/device/mem_info_vram_used" ]; then
              vram_used=$(cat "$card/device/mem_info_vram_used" 2>/dev/null)
              vram_total=$(cat "$card/device/mem_info_vram_total" 2>/dev/null)
              [ -n "$vram_used" ] && echo "amdgpu_vram_used_bytes $vram_used"
              [ -n "$vram_total" ] && echo "amdgpu_vram_total_bytes $vram_total"
            fi

            # GPU utilization
            if [ -f "$card/device/gpu_busy_percent" ]; then
              gpu_busy=$(cat "$card/device/gpu_busy_percent" 2>/dev/null)
              [ -n "$gpu_busy" ] && echo "amdgpu_utilization_percent $gpu_busy"
            fi

            sleep ${scrapeInterval}
          done | ${pkgs.prometheus-node-exporter}/bin/node_exporter \
            --web.listen-address=":${toString ports.amdgpu}" \
            --collector.textfile.directory=/dev/stdin \
            --collector.disable-defaults \
            --no-collector.arp \
            --no-collector.bcache \
            --no-collector.bonding \
            --no-collector.btrfs \
            --no-collector.conntrack \
            --no-collector.cpu \
            --no-collector.cpufreq \
            --no-collector.diskstats \
            --no-collector.dmi \
            --no-collector.edac \
            --no-collector.entropy \
            --no-collector.fibrechannel \
            --no-collector.filefd \
            --no-collector.filesystem \
            --no-collector.hwmon \
            --no-collector.infiniband \
            --no-collector.ipvs \
            --no-collector.loadavg \
            --no-collector.mdadm \
            --no-collector.meminfo \
            --no-collector.netclass \
            --no-collector.netdev \
            --no-collector.netstat \
            --no-collector.nfs \
            --no-collector.nfsd \
            --no-collector.nvme \
            --no-collector.os \
            --no-collector.powersupplyclass \
            --no-collector.pressure \
            --no-collector.rapl \
            --no-collector.schedstat \
            --no-collector.selinux \
            --no-collector.sockstat \
            --no-collector.softnet \
            --no-collector.stat \
            --no-collector.tapestats \
            --no-collector.textfile \
            --no-collector.thermal_zone \
            --no-collector.time \
            --no-collector.timex \
            --no-collector.udp_queues \
            --no-collector.uname \
            --no-collector.vmstat \
            --no-collector.xfs \
            --no-collector.zfs
        ''}";

        Restart = "always";
        User = "nobody";

        # Security hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };

    # Create textfile collector directory
    systemd.tmpfiles.rules = lib.mkIf cfg.enablePowertopExporter [
      "d ${cfg.textfileCollectorPath} 0755 prometheus prometheus -"
    ];

    # Powertop exporter script
    environment.etc."prometheus-exporters/powertop-exporter.sh" = lib.mkIf cfg.enablePowertopExporter {
      mode = "0755";
      text = ''
        #!/bin/sh
        # Powertop exporter for Prometheus node_exporter textfile collector

        TEXTFILE_DIR="${cfg.textfileCollectorPath}"
        TMP_METRICS_FILE=$(mktemp)

        # Run powertop for 5 seconds to generate a CSV report
        ${pkgs.powertop}/bin/powertop --csv -t 5 > /tmp/powertop.csv 2>/dev/null

        if [ $? -ne 0 ]; then
            echo "Failed to run powertop" >&2
            exit 1
        fi

        # Header for the metrics
        echo '# HELP powertop_power_estimate_watts Estimated power consumption by process or device in watts.' > "$TMP_METRICS_FILE"
        echo '# TYPE powertop_power_estimate_watts gauge' >> "$TMP_METRICS_FILE"
        echo '# HELP powertop_usage_percent Usage percentage of a device or process.' >> "$TMP_METRICS_FILE"
        echo '# TYPE powertop_usage_percent gauge' >> "$TMP_METRICS_FILE"
        echo '# HELP powertop_wakeups_per_second Wakeups from idle per second by a process or device.' >> "$TMP_METRICS_FILE"
        echo '# TYPE powertop_wakeups_per_second gauge' >> "$TMP_METRICS_FILE"

        # Parse the CSV file
        ${pkgs.gawk}/bin/awk -F';' '
        BEGIN { OFS="" }
        NR > 1 {
            # Clean up the description
            description=$1;
            gsub(/"/, "", description);
            gsub(/\\/, "\\\\", description);
            gsub(/\n/, "\\n", description);
            gsub(/\[|\]/, "", description);
            gsub(/ /, "_", description);
            gsub(/-/, "_", description);
            gsub(/\./, "", description);
            gsub(/:/, "", description);
            gsub(/\//, "_", description);

            # Power Estimate
            power_col = NF-2;
            power_val = $power_col;
            if (power_val ~ /[0-9.]+(W|mW|uW)/) {
                unit = substr(power_val, length(power_val));
                val = substr(power_val, 1, length(power_val)-2);
                if (unit == "m") val /= 1000;
                if (unit == "u") val /= 1000000;
                print "powertop_power_estimate_watts{description=\"" description "\"} " val;
            }

            # Usage
            usage_col = 2;
            usage_val = $usage_col;
            if (usage_val ~ /[0-9.]+%/) {
                val = substr(usage_val, 1, length(usage_val)-1);
                print "powertop_usage_percent{description=\"" description "\"} " val;
            }

            # Wakeups/s
            wakeups_col = 3;
            wakeups_val = $wakeups_col;
            if (wakeups_val ~ /[0-9.]+/) {
                 print "powertop_wakeups_per_second{description=\"" description "\"} " wakeups_val;
            }
        }
        ' /tmp/powertop.csv >> "$TMP_METRICS_FILE"

        # Atomically move to final destination
        ${pkgs.moreutils}/bin/sponge "$TEXTFILE_DIR/powertop.prom" < "$TMP_METRICS_FILE"
        rm -f "$TMP_METRICS_FILE"
      '';
    };

    # Powertop exporter timer and service
    systemd.services.prometheus-powertop-exporter = lib.mkIf cfg.enablePowertopExporter {
      description = "Powertop metrics exporter for Prometheus";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/etc/prometheus-exporters/powertop-exporter.sh";
        User = "root"; # powertop requires root

        # Security hardening where possible
        PrivateTmp = true;
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };

    systemd.timers.prometheus-powertop-exporter = lib.mkIf cfg.enablePowertopExporter {
      description = "Run powertop exporter periodically";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = if cfg.powerEfficient then "2min" else "1min";
        Persistent = true;
      };
    };

    # Dashboard provisioning can be added later
    # For now, import dashboards manually via Grafana UI using ID 1860 (Node Exporter Full)
    # and the custom power efficiency dashboard
  };
}
