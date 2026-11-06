{
  config,
  lib,
  pkgs,
  ...
}: let
  textfileDir = "/var/lib/node-exporter-textfile";

  # NVMe SMART and ZFS error counters, which node-exporter doesn't expose. Root,
  # like the other textfile writers, for /dev/nvme* and /dev/zfs. The NVMe
  # error-log count is left out on purpose: the Crucial P5 logs a harmless
  # "Invalid Field in Command" for every unsupported admin query (294 of them).
  healthTextfile = pkgs.writeShellScript "hw-health-textfile" ''
    set -euo pipefail
    shopt -s nullglob # orchid-vm has no NVMe
    export PATH=${lib.makeBinPath [pkgs.coreutils pkgs.jq pkgs.nvme-cli config.boot.zfs.package]}

    tmp=$(mktemp ${textfileDir}/hw-health.prom.XXXXXX)
    chmod 0644 "$tmp"
    {
      for dev in /dev/nvme[0-9]; do
        nvme smart-log "$dev" -o json | jq -r --arg d "''${dev#/dev/}" '
          "node_nvme_critical_warning{device=\"\($d)\"} \(.critical_warning)",
          "node_nvme_media_errors_total{device=\"\($d)\"} \(.media_errors)"'
      done
      zpool status -j --json-int | jq -r '.pools[] | .name as $p |
        "node_zpool_data_errors{zpool=\"\($p)\"} \(.error_count)",
        (.vdevs[] | .. | objects | select(.vdev_type == "disk") |
          "node_zpool_vdev_errors{zpool=\"\($p)\",vdev=\"\(.name)\"} \(.read_errors + .write_errors + .checksum_errors)")'
    } > "$tmp"
    mv "$tmp" ${textfileDir}/hw-health.prom
  '';

  # Prometheus has no Alertmanager here, so this polls its firing alerts and
  # raises a desktop notification once per firing episode.
  notify = pkgs.writeShellScript "hw-alert-notify" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [pkgs.coreutils pkgs.curl pkgs.gnugrep pkgs.jq pkgs.libnotify]}

    seen=$XDG_RUNTIME_DIR/hw-alerts.seen
    touch "$seen"
    firing=$(curl -sf http://localhost:${toString config.services.prometheus.port}/api/v1/alerts |
      jq -c '.data.alerts[] | select(.state == "firing")') || exit 0

    : > "$seen.new"
    while IFS= read -r a; do
      [ -n "$a" ] || continue
      key=$(jq -c .labels <<<"$a")
      echo "$key" >> "$seen.new"
      grep -Fxq "$key" "$seen" ||
        notify-send -u critical -a orchid "$(jq -r .labels.alertname <<<"$a")" "$(jq -r '.annotations.summary // ""' <<<"$a")"
    done <<<"$firing"
    mv "$seen.new" "$seen"
  '';

  rules = {
    groups = [
      {
        name = "hardware";
        rules = [
          {
            # The RAM corrupted data at 72 °C under the old fan curve (2026-10-09)
            # and passed 4 h of stressapptest at 57 °C; fan-control.py keeps it below 60.
            alert = "RamHot";
            expr = ''node_hwmon_temp_celsius * on(chip) group_left() node_hwmon_chip_names{chip_name="spd5118"} > 60'';
            for = "5m";
            annotations.summary = ''RAM at {{ $value | printf "%.0f" }} °C (keep below 60; it corrupted data at 72). Check the case fans and fan-control.'';
          }
          {
            # GPU junction/memory and NVMe, against each sensor's own limit.
            alert = "NearThermalLimit";
            expr = ''(node_hwmon_temp_celsius > node_hwmon_temp_crit_celsius - 5) * on(chip) group_left(chip_name) node_hwmon_chip_names * on(chip, sensor) group_left(label) node_hwmon_sensor_label'';
            for = "1m";
            annotations.summary = ''{{ $labels.chip_name }} {{ $labels.label }} at {{ $value | printf "%.0f" }} °C, within 5 °C of its limit.'';
          }
          {
            alert = "NvmeCriticalWarning";
            expr = "node_nvme_critical_warning != 0";
            annotations.summary = "{{ $labels.device }} reports SMART critical warning {{ $value }}. Run: sudo smartctl -a /dev/{{ $labels.device }}";
          }
          {
            alert = "NvmeMediaErrors";
            expr = "node_nvme_media_errors_total > 0";
            annotations.summary = "{{ $labels.device }} has {{ $value }} media errors: the flash is failing. Check backups.";
          }
          {
            alert = "ZfsPoolNotOnline";
            expr = ''node_zfs_zpool_state{state!="online"} == 1'';
            annotations.summary = "ZFS pool {{ $labels.zpool }} is {{ $labels.state }}. Run: zpool status -v";
          }
          {
            alert = "ZfsErrors";
            expr = "node_zpool_vdev_errors > 0 or node_zpool_data_errors > 0";
            annotations.summary = "ZFS pool {{ $labels.zpool }} has {{ $value }} errors. Run: zpool status -v";
          }
          {
            # Without this, a broken collector would just mean no alerts, ever.
            alert = "HwHealthStale";
            expr = ''time() - node_textfile_mtime_seconds{file=~".*hw-health.prom"} > 900 or absent(node_textfile_mtime_seconds{file=~".*hw-health.prom"})'';
            for = "10m";
            annotations.summary = "NVMe/ZFS health data is stale. Check: systemctl status hw-health-textfile";
          }
        ];
      }
    ];
  };
in {
  # JSON is valid YAML; promtool checks the rules when the config builds.
  services.prometheus.ruleFiles = [(pkgs.writeText "hw-alerts.yml" (builtins.toJSON rules))];

  systemd.services.hw-health-textfile = {
    description = "Publish NVMe SMART and ZFS error counts for the node-exporter textfile collector";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = healthTextfile;
    };
  };
  systemd.timers.hw-health-textfile = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
    };
  };

  systemd.user.services.hw-alert-notify = {
    description = "Desktop notifications for firing Prometheus hardware alerts";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = notify;
    };
  };
  systemd.user.timers.hw-alert-notify = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "1min";
    };
  };
}
