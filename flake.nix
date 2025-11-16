{
  description = "NixOS configurations for asdrubalinea 🏳️‍⚧️";

  inputs = {
    # --- Nixpkgs Channels ---
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";
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
    helix = {
      url = "github:usagi-flow/evil-helix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # claude-desktop.url = "github:k3d3/claude-desktop-linux-flake";
    # claude-desktop.inputs.nixpkgs.follows = "nixpkgs";
    hn-tui-flake = {
      url = "github:asdrubalinea/hn-tui-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ nixpkgs
    , nixpkgs-stable
    , nixpkgs-trunk
    , nixpkgs-custom
    , home-manager
    , hyprland
    , niri
    , vscode-server
    , disko
    , impermanence
    , stylix
    , sops-nix
    , nixos-hardware
    , emacs-overlay
    , lanzaboote
    , ucodenix
    , ...
    }:
    let
      system = "x86_64-linux";

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

      overlays = [
        multiChannelOverlay
        emacs-overlay.overlay
        niri.overlays.niri
      ];

      nixpkgsConfig = {
        allowUnfree = true;
        rocmSupport = true;
      };

      mkPkgs = args:
        import nixpkgs ({
          inherit system;
          config = nixpkgsConfig;
          overlays = overlays;
        } // args);

      lib = nixpkgs.lib;
    in
    {
      nixosConfigurations = {
        "orchid" = lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            hostname = "orchid";
          };

          modules = [
            {
              nixpkgs = {
                config = nixpkgsConfig;
                overlays = overlays;
              };
            }
            niri.nixosModules.niri

            ./hosts/orchid.nix
          ];
        };

        tempest = lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            hostname = "tempest";
          };

          modules = [
            {
              nixpkgs = {
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

            ./disks/tempest.nix
            ./hosts/tempest/default.nix

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                extraSpecialArgs = {
                  inherit inputs;
                  hostname = "tempest";
                };
                backupFileExtension = "backup";
                useGlobalPkgs = false;
                useUserPackages = true;
                sharedModules = [
                  {
                    nixpkgs = {
                      config = nixpkgsConfig;
                      overlays = overlays;
                    };
                  }
                ];

                users = {
                  irene = import ./homes/tempest.nix;
                  # plasma = import ./homes/plasma.nix;
                };
              };
            }
          ];
        };
      };

      homeConfigurations = {
        "irene@orchid" = home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs { };
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
      };
    };
}
