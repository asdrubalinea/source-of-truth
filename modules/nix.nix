{
  pkgs,
  lib,
  config,
  ...
}: {
  nix = {
    package = pkgs.lix;
    nixPath = ["nixpkgs=flake:nixpkgs"];

    settings = {
      trusted-users = [
        "root"
        "irene"
      ];

      substituters =
        [
          "https://cache.nixos.org/"
          "https://cache.numtide.com" # numtide/llm-agents.nix (codex); needs that input NOT following nixpkgs, see flake.nix
        ]
        ++ (
          if config.networking.hostName == "tempest"
          then [
            # "http://orchid.boreal-city.ts.net:8501/"
            "https://noctalia.cachix.org" # prebuilt Noctalia v5 / Quickshell (needs noctalia input NOT following nixpkgs; see flake.nix)
            # "https://cache.garnix.io" # disabled: R2 backend unreachable from this network
          ]
          else [
            "https://hyprland.cachix.org"
            "https://cosmic.cachix.org/"
          ]
        );
      # No CachyOS kernel cache: xddxdd's attic (lantian) was taken down after a
      # server compromise (xddxdd/nix-cachyos-kernel#110) and its signing key is
      # no longer trusted, so the kernel builds locally on every host.

      # Corresponding public keys
      trusted-public-keys =
        [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        ]
        ++ (
          if config.networking.hostName == "tempest"
          then [
            "orchid:OonqQD3i5uEEi8h3zSxxp/uvVGR+Mum0/mbJohLJ09I="
            "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
            # "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
          ]
          else [
            "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
            "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
          ]
        );

      # A dead substituter must not fail the build: fallback makes nix skip a
      # cache whose narinfo query errors (and disable it for 60s) instead of
      # aborting, and connect-timeout makes each attempt cost 5s, not curl's
      # ~80s × 5 retries. Cost: a build that a down cache would have served
      # compiles locally rather than erroring out.
      fallback = true;
      connect-timeout = 5;

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
      dates = lib.mkDefault ["weekly"];
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
