{ pkgs, lib, config, ... }:
{
  nix = {
    package = pkgs.nixVersions.stable;
    nixPath = [ "nixpkgs=flake:nixpkgs" ];

    settings = {
      trusted-users = [
        "root"
        "irene"
      ];

      substituters = [
        "https://cache.nixos.org/"
      ] ++ (
        if config.networking.hostName == "tempest" then [
          # "http://orchid.boreal-city.ts.net:8501/"
          "https://attic.xuyh0120.win/lantian"
          "https://cache.garnix.io"
        ]
        else [
          "https://hyprland.cachix.org"
          "https://cosmic.cachix.org/"
        ]
      );

      # Corresponding public keys
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ] ++ (
        if config.networking.hostName == "tempest" then [
          "orchid:OonqQD3i5uEEi8h3zSxxp/uvVGR+Mum0/mbJohLJ09I="
          "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
          "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
        ]
        else [
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
          "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
        ]
      );

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

    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
  };
}
