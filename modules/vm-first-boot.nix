{pkgs, ...}: {
  # First-boot fixups shared by the disko VM clones (hosts/*/vm.nix, imported
  # only when the `virtual` specialArg is true). Both were found the hard way on
  # tempest-vm; neither can affect a physical host, since nothing else imports
  # this file.

  # home-manager activates via home-manager-irene.service, but the NixOS module
  # only orders it `after nix-daemon.socket` — NOT after impermanence binds
  # /persist/home/irene over /home/irene (a systemd `home-irene.mount` unit). So
  # on first boot HM writes into the pre-bind directory and the bind then masks
  # everything, which is why the home looks empty until a manual `home-manager
  # switch` (by then the mount is up). RequiresMountsFor makes systemd pull in
  # and order after the bind mount, so activation lands in the persisted home.
  systemd.services.home-manager-irene = {
    unitConfig.RequiresMountsFor = "/home/irene";
    after = ["home-irene.mount"];
    requires = ["home-irene.mount"];
  };

  # Declaratively seed the (public) flake into /persist — a real ZFS dataset in
  # these VMs — so `nh` and the doc paths resolve exactly like on the real host.
  # Idempotent: ConditionPathExists skips the clone if the tree already exists.
  systemd.services.seed-source-of-truth = {
    description = "Clone source-of-truth into /persist";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    path = [pkgs.git];
    unitConfig = {
      ConditionPathExists = "!/persist/source-of-truth/.git";
      # Retry a handful of times: network-online.target can fire before DNS/egress
      # is actually usable, and without this a single early failure would leave
      # /persist/source-of-truth absent for the whole boot (programs.nh.flake then
      # has no flake). Stop after StartLimitBurst tries so a genuinely offline VM
      # doesn't loop forever.
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };
    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      RestartSec = 15;
      # Clean up a half-finished clone so the retry starts from a clean slate
      # (git clone refuses a non-empty target).
      ExecStartPre = "${pkgs.coreutils}/bin/rm -rf /persist/source-of-truth";
      ExecStart =
        "${pkgs.git}/bin/git clone "
        + "https://github.com/asdrubalinea/source-of-truth /persist/source-of-truth";
    };
  };
}
