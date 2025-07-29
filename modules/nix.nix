{ pkgs, lib, config, ... }:
{
  # Shared Nix configuration across all hosts
  nix = {
    package = pkgs.nixVersions.stable;

    settings = {
      # Base trusted users - hosts can extend this list
      trusted-users = [
        "root"
        "irene"
      ];

      # Common substituters for performance
      substituters = [
        "https://cache.nixos.org/"
        "https://hyprland.cachix.org"
        "https://cosmic.cachix.org/"
      ];

      # Corresponding public keys
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      ];

      # Performance optimizations
      max-jobs = lib.mkDefault "auto";
      cores = lib.mkDefault 0; # Use all available cores

      # Enable experimental features globally
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    # Optimize store and enable garbage collection
    optimise = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault [ "weekly" ];
    };

    gc = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault "weekly";
      options = lib.mkDefault "--delete-older-than 30d";
    };

    # Additional options for modern Nix usage
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
  };

}
