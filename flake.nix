{
  description = "NixOS configurations for asdrubalinea 🏳️‍⚧️";

  inputs = {
    # --- Nixpkgs Channels ---
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Separate unstable input so tempest's standalone home build can be advanced
    # independently of the system channel (nix flake update nixpkgs-home).
    nixpkgs-home.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-trunk.url = "github:nixos/nixpkgs";
    nixpkgs-custom.url = "github:nixos/nixpkgs";

    # --- Core Components ---
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ucodenix.url = "github:e-tho/ucodenix";
    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel/release";
      # Do NOT override nixpkgs — upstream's lantian attic cache only has
      # store paths built against its pinned nixpkgs. Following ours forces
      # a full local kernel rebuild on every change.
    };

    # --- Desktop/UI Components ---
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprtasking = {
      url = "github:raybbian/hyprtasking";
      inputs.hyprland.follows = "hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #rose-pine-hyprcursor = {
    #url = "github:ndom91/rose-pine-hyprcursor";
    #inputs.nixpkgs.follows = "nixpkgs";
    #inputs.hyprlang.follows = "hyprland/hyprlang";
    #};
    nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
    anyrun = {
      url = "github:anyrun-org/anyrun";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- Applications/Services ---
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    diapee-bot = {
      url = "github:asdrubalinea/diapee-bot/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tribunale-scrape = {
      url = "github:asdrubalinea/tribunale-scrape";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    auxologico-check = {
      url = "github:asdrubalinea/auxologico-check";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flights = {
      url = "github:asdrubalinea/flights";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helix = {
      url = "github:mattwparas/helix/steel-event-system";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hn-tui-flake = {
      url = "github:asdrubalinea/hn-tui-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex.url = "github:sadjow/codex-cli-nix";
    claude-code.url = "github:sadjow/claude-code-nix";
    framework-control.url = "github:ozturkkl/framework-control";
    drift = {
      url = "github:phlx0/drift";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    nixpkgs,
    nixpkgs-home,
    nixpkgs-stable,
    nixpkgs-trunk,
    nixpkgs-custom,
    home-manager,
    hyprland,
    niri,
    vscode-server,
    disko,
    impermanence,
    stylix,
    sops-nix,
    nixos-hardware,
    emacs-overlay,
    lanzaboote,
    ucodenix,
    codex,
    claude-code,
    nix-cachyos-kernel,
    ...
  }: let
    defaultSystem = "x86_64-linux";

    multiChannelOverlay = final: prev: {
      stable = import nixpkgs-stable {
        system = final.stdenv.hostPlatform.system;
        config = final.config;
      };

      trunk = import nixpkgs-trunk {
        system = final.stdenv.hostPlatform.system;
        config = final.config;
      };

      custom = import nixpkgs-custom {
        system = final.stdenv.hostPlatform.system;
        config = final.config;
      };
    };

    # Steel plugin language is not a default cargo feature
    # (helix-term: `default = ["git"]`), so enable it here. The fork's
    # default.nix vendors deps via cargoLock + allowBuiltinFetchGit, so adding
    # a build feature needs no hash change. Note: buildRustPackage reads the
    # `cargoBuildFeatures` env var (mapped from its `buildFeatures` arg *inside*
    # the function), so overriding `buildFeatures` here would be ignored — we
    # must set `cargoBuildFeatures` directly via overrideAttrs.
    helixSteelOverlay = final: prev: {
      helix =
        (inputs.helix.packages.${final.stdenv.hostPlatform.system}.default).overrideAttrs
        (old: {
          cargoBuildFeatures = (old.cargoBuildFeatures or []) ++ ["steel"];
        });
    };

    overlays = [
      multiChannelOverlay
      helixSteelOverlay
      emacs-overlay.overlay
      niri.overlays.niri
      claude-code.overlays.default
      nix-cachyos-kernel.overlays.default
    ];

    nixpkgsConfig = {
      allowUnfree = true;
      # rocmSupport = true;
    };

    mkPkgs = args:
      import nixpkgs ({
          system = defaultSystem;
          config = nixpkgsConfig;
          overlays = overlays;
        }
        // args);

    # Same shape as mkPkgs but built from the independent nixpkgs-home input,
    # so tempest's standalone home generation can be bumped without touching
    # the system channel. The stable/trunk/custom overlays continue to pull
    # from their own inputs, so `pkgs.stable.foo` still works.
    mkHomePkgs = args:
      import nixpkgs-home ({
          system = defaultSystem;
          config = nixpkgsConfig;
          overlays = overlays;
        }
        // args);

    lib = nixpkgs.lib;
  in {
    # Expose the locked home-manager CLI so it can be bootstrapped without
    # relying on whatever's in PATH — useful right after a config-apply that
    # tears down /etc/profiles/per-user/irene before the first standalone HM
    # activation:
    #   nix run /persist/source-of-truth#home-manager -- switch \
    #     --flake '.#irene@tempest' -b backup
    packages.${defaultSystem}.home-manager =
      home-manager.packages.${defaultSystem}.default;

    nixosConfigurations = {
      "orchid" = lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          hostname = "orchid";
        };

        modules = [
          {
            nixpkgs = {
              hostPlatform = defaultSystem;
              config = nixpkgsConfig;
              overlays = overlays;
            };
          }
          niri.nixosModules.niri

          ./hosts/orchid/default.nix
        ];
      };

      tempest = lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          hostname = "tempest";
        };

        modules = [
          {
            nixpkgs = {
              hostPlatform = defaultSystem;
              config = nixpkgsConfig;
              overlays = overlays;
            };
          }
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence
          nixos-hardware.nixosModules.framework-amd-ai-300-series
          lanzaboote.nixosModules.lanzaboote
          ucodenix.nixosModules.default
          niri.nixosModules.niri
          inputs.framework-control.nixosModules.default

          ./disks/tempest.nix
          ./hosts/tempest/default.nix
        ];
      };

      hydra = lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          hostname = "hydra";
        };

        modules = [
          {
            nixpkgs = {
              hostPlatform = defaultSystem;
              config = nixpkgsConfig;
              overlays = overlays;
            };
          }
          disko.nixosModules.disko

          ./disks/hydra.nix
          ./hosts/hydra/default.nix
        ];
      };
    };

    homeConfigurations = {
      "irene@orchid" = home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgs {};
        extraSpecialArgs = {
          inherit inputs;
          hostname = "orchid";
        };

        modules = [
          hyprland.homeManagerModules.default
          vscode-server.homeModules.default
          niri.homeModules.config
          stylix.homeModules.stylix

          ./homes/orchid.nix

          {
            home = {
              username = "irene";
              homeDirectory = "/home/irene";
              stateVersion = "23.05";
            };
          }
        ];
      };

      "irene@tempest" = home-manager.lib.homeManagerConfiguration {
        pkgs = mkHomePkgs {};
        extraSpecialArgs = {
          inherit inputs;
          hostname = "tempest";
        };

        modules = [
          # hyprland + stylix HM modules are imported inside homes/tempest.nix.
          # niri.homeModules.config has to be added here because in the previous
          # nixos-module form it was auto-wired by niri.nixosModules.niri; in
          # standalone HM it has to be imported explicitly so programs.niri.*
          # options exist.
          niri.homeModules.config

          ./homes/tempest.nix
        ];
      };
    };
  };
}
