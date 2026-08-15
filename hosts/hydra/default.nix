{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./hardware.nix

    ./system/boot.nix
    ./system/localization.nix
    ./system/networking.nix
    ./system/security.nix
    ./system/services.nix
    ../../services/vaultwarden-mirror.nix
    ./system/environment.nix

    ./users/irene.nix

    ../../modules/nix.nix
    ../../services/caddy
  ];

  # `nh os switch` / `nh clean all` — replaces the old config-apply /
  # system-clear wrappers. Sets NH_FLAKE so both work from any directory.
  programs.nh = {
    enable = true;
    flake = "/home/irene/source-of-truth";

    # Weekly GC across system + user profiles. See hosts/tempest/default.nix.
    clean = {
      enable = true;
      extraArgs = "--keep 5 --keep-since 7d";
    };
  };

  # Mutually exclusive with programs.nh.clean; modules/nix.nix defaults it on.
  nix.gc.automatic = false;

  system.stateVersion = "24.11";
}
