{ ... }:
{
  programs.nix-ld.enable = true;
  services = {
    borg-backup = {
      enable = true;
      jobs.home-irene = {
        user = "irene";
        repo = "ssh://u518612@u518612.your-storagebox.de:23/./backups/tempest-home-irene";
        ssh_key_file = "/home/irene/.ssh/id_ed25519";
        password_file = "/persist/borg-home-backup/passphrase";
        paths = [ "/home/irene" ];
      };
    };

    openssh.enable = true;

    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };

    monitoring = {
      enable = false;
      powerEfficient = true;
    };
  };
}
