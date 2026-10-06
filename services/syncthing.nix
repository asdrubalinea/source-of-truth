{
  lib,
  hostname,
  ...
}: let
  # Syncthing device IDs, one per host that imports this module. They are
  # derived from the device's TLS certificate, which syncthing generates on its
  # first start, so a freshly installed host has none until after its first
  # `apply`. Read it with `syncthing device-id --home=/persist/syncthing-config`,
  # fill it in here, apply everywhere. A `null` entry simply isn't paired. The
  # IDs are public (they're what you'd read off the GUI to pair), not secrets.
  deviceIds = {
    tempest = "QXCWUOD-WJAD3EL-XP4BYDZ-ITIUWTP-27CQLA6-37YC6BU-5NGSLJQ-BRFELQK";
    orchid = "ICYTLBY-QCF6HUD-VQAPFBR-47KFPST-4F5CIG3-H5SY7I3-65XN2ID-CGFM7Q2";
  };

  peers = lib.filterAttrs (name: id: name != hostname && id != null) deviceIds;
in {
  services = {
    syncthing = {
      enable = true;
      user = "irene";
      # Bind the (unauthenticated-by-default) GUI/API to loopback only; reach it
      # via an SSH tunnel rather than exposing it on the LAN/tailnet.
      guiAddress = "127.0.0.1:8384";

      dataDir = "/home/irene/";
      configDir = "/persist/syncthing-config/";

      # Fully declarative: devices and folders set in the GUI are reverted on
      # the next activation (the module's overrideDevices/overrideFolders
      # defaults). Pairing is editing `deviceIds` above, not clicking Accept.
      settings = {
        options.urAccepted = -1; # no usage reporting

        devices = lib.mapAttrs (name: id: {inherit id;}) peers;

        folders.helium = {
          # The Helium browser profile, roamed whole between tempest and orchid.
          # This only works because the two are never used at the same time:
          # the profile is a pile of SQLite databases and two writers through a
          # file sync corrupt them. pkgs.helium (packages/helium.nix) refuses
          # to start while this folder is still syncing, and reports when the
          # other side has everything after a quit. See docs/helium-sync.md.
          label = "Helium profile";
          path = "/home/irene/.config/net.imput.helium";
          devices = lib.attrNames peers;
          # Keep the last few replaced versions of each file: a sync that
          # lands a half-written database is recoverable from .stversions.
          versioning = {
            type = "simple";
            params.keep = "3";
          };
          # Per-machine state and caches. A bare name matches at any depth
          # (syncthing adds the `**/` itself); a leading `/` anchors it to the
          # profile root. `(?d)` lets syncthing delete the match when it has to
          # remove its parent directory.
          ignorePatterns = [
            "// Singleton* are symlinks naming THIS host's pid: synced, they make"
            "// the other host believe the profile is already open."
            "(?d)Singleton*"
            "// SQLite/LevelDB locks and journals; all gone when Helium is closed."
            "(?d)LOCK"
            "(?d)LOG"
            "(?d)LOG.old"
            "(?d)*-journal"
            "(?d)*-wal"
            "(?d)*-shm"
            "(?d)*.tmp"
            "(?d).org.chromium.Chromium.*"
            "// Caches: regenerated, and most of the profile's bytes."
            "(?d)Cache"
            "(?d)Code Cache"
            "(?d)GPUCache"
            "(?d)DawnGraphiteCache"
            "(?d)DawnWebGPUCache"
            "(?d)GrShaderCache"
            "(?d)ShaderCache"
            "(?d)GraphiteDawnCache"
            "(?d)Service Worker"
            "(?d)blob_storage"
            "(?d)optimization_guide_*"
            "// Per-machine, root-level: downloaded components, metrics, crash dumps."
            "(?d)/component_crx_cache"
            "(?d)/GPUPersistentCache"
            "(?d)/BrowserMetrics*"
            "(?d)/DeferredBrowserMetrics"
            "(?d)/Crash Reports"
            "(?d)/CertificateRevocation"
            "(?d)/WidevineCdm"
            "(?d)/segmentation_platform"
            "(?d)/Webstore Downloads"
            "(?d)/Variations"
          ];
        };
      };
    };
  };

  # Sync traffic (22000) and local discovery (21027), tailnet only: the two
  # hosts are never on the same LAN, and tempest's firewall is otherwise closed.
  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [22000];
    allowedUDPPorts = [22000 21027];
  };

  # configDir is outside /var/lib, so the module's StateDirectory does not cover
  # it — and on a freshly formatted pool /persist is root:root 0755, so syncthing
  # (running as irene) cannot create it. The unit then fails five times in two
  # seconds and start-limit-hits: "Failed to ensure directory exists (error=
  # \"mkdir /persist/syncthing-config: permission denied\")". Only shows up on the
  # FIRST boot after an install, which is exactly why it went unnoticed — found by
  # booting orchid-vm on a fresh pool. 0700 because this directory holds the
  # device's private key and cert.
  systemd.tmpfiles.rules = ["d /persist/syncthing-config 0700 irene users -"];
}
