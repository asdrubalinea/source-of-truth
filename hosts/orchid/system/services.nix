{inputs, ...}: let
  system = "x86_64-linux";
  getNixosModule = flake:
    if flake ? nixosModules && flake.nixosModules ? default
    then flake.nixosModules.default
    else flake.nixosModules.${system}.default;
in {

  # The Hetzner storage box that backs every borg job below. Declared here so a
  # fresh install can run its first backup without an interactive host-key
  # prompt — /home/irene/.ssh/known_hosts is empty on a new pool.
  programs.ssh.knownHosts = {
    "[u518612.your-storagebox.de]:23" = {
      hostNames = ["[u518612.your-storagebox.de]:23"];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
    };
  };


  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    permitCertUid = "caddy";
    extraSetFlags = ["--advertise-exit-node"];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      KbdInteractiveAuthentication = false;
    };
  };

  # nix.gc.automatic, which hosts/orchid/default.nix already sets alongside
  # programs.nh.clean.
}
