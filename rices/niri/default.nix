{ lib, ... }:
{
  imports = [
    ./alacritty.nix
    ./kitty.nix
    ./wezterm.nix
    ./niri.nix
    ./flights.nix
    ./swayidle.nix
    ./noctalia.nix
    ./noctalia-widgets.nix
    ./wallpaper
    ./stylix.nix
  ];

  # The niri rice as a single enable-options Home-Manager module. Importing this
  # directory only *declares* the rice; `rices.niri.enable = true` (set per-host,
  # e.g. homes/tempest/default.nix) activates it — every submodule's config is
  # gated on it. This deliberately deviates from the repo's "explicit imports,
  # no options layer" convention; see docs/adr/0004-niri-rice-as-enable-module.md.
  #
  # Machine policy lives OUTSIDE the rice: the monitor layout (kanshi) moved to
  # homes/tempest/monitors.nix, and the backup-health readout's watched units are
  # the options below — defaulting to tempest's, and the readout collapses to
  # nothing on a host where they're absent. See "machine policy" in CONTEXT.md.
  options.rices.niri = {
    enable = lib.mkEnableOption "the niri desktop rice";

    backupWidget = {
      borgUnit = lib.mkOption {
        type = lib.types.str;
        default = "borgbackup-job-home-irene.service";
        description = ''
          systemd unit for the borg (offsite) backup leg watched by the bar's
          storage/backup health readout.
        '';
      };
      usbUnit = lib.mkOption {
        type = lib.types.str;
        default = "tempest-backup-external.service";
        description = ''
          systemd unit for the syncoid (USB) backup leg.
        '';
      };
      syncoidSnapshotPrefix = lib.mkOption {
        type = lib.types.str;
        default = "syncoid_tempest";
        description = ''
          Prefix of the syncoid sync-snapshots used to date the last successful
          USB replication (the syncoid service no-ops when the drive is absent,
          so its own run time is unreliable).
        '';
      };
    };
  };
}
