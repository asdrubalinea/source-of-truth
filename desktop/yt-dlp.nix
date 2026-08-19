# yt-dlp, plus the local PO-token server it needs to get anything off YouTube.
# The wrapper (and the reasoning behind it) is ../packages/yt-dlp-pot.nix; this
# module is only the two halves that have to exist at runtime: the binary on
# PATH, and the provider it talks to.
{pkgs, ...}: {
  home.packages = [(pkgs.callPackage ../packages/yt-dlp-pot.nix {})];

  # A daemon rather than something spawned per download: the plugin's HTTP
  # provider has no way to start one, and the alternative script mode wants a
  # `generate_once.js` that the nixpkgs package does not install. Idle cost is
  # one node process.
  #
  # It binds [::]:4416 with no option to narrow that (the server takes only
  # --port), so what keeps it off the network is the host firewall — enabled with
  # an empty allowedTCPPorts in hosts/tempest/system/networking.nix. Anything
  # that opens ports on a host running this should leave 4416 closed.
  systemd.user.services.bgutil-pot-provider = {
    Unit = {
      Description = "PO-token provider for yt-dlp";
      Documentation = "https://github.com/Brainicism/bgutil-ytdlp-pot-provider";
    };

    Service = {
      ExecStart = "${pkgs.python3Packages.bgutil-ytdlp-pot-provider}/bin/bgutil-ytdlp-pot-provider";
      Restart = "on-failure";
    };

    Install.WantedBy = ["default.target"];
  };
}
