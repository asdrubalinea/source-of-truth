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
    nixvim = {
      url = "github:asdrubalinea/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    diapee-bot = {
      url = "github:asdrubalinea/diapee-bot/llms";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helix = {
      url = "github:usagi-flow/evil-helix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-desktop.url = "github:k3d3/claude-desktop-linux-flake";
    claude-desktop.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      nixpkgs,
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
      ...
    }:
    let
      system = "x86_64-linux";

      multiChannelOverlay = final: prev: {
        stable = import nixpkgs-stable {
          system = final.system;
          config = final.config;
        };

        trunk = import nixpkgs-trunk {
          system = final.system;
          config = final.config;
        };

        custom = import nixpkgs-custom {
          system = final.system;
          config = final.config;
        };
      };

      pkgs = import nixpkgs {
        inherit system;

        config = {
          allowUnfree = true;
          rocmSupport = true;
        };

        overlays = [
          multiChannelOverlay
          emacs-overlay.overlay
        ];
      };

      lib = nixpkgs.lib;
    in
    {
      nixosConfigurations = {
        "orchid" = lib.nixosSystem {
          inherit system pkgs;
          specialArgs = {
            inherit inputs;
            hostname = "orchid";
          };

          modules = [
            niri.nixosModules.niri

            ./hosts/orchid.nix
          ];
        };

        live = nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          specialArgs = { inherit inputs; };

          modules = [
            (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")

            ./hosts/tempest.nix
          ];
        };

        tempest = lib.nixosSystem {
          inherit system pkgs;
          specialArgs = {
            inherit inputs;
            hostname = "tempest";
          };

          modules = [
            disko.nixosModules.disko
            impermanence.nixosModules.impermanence
            nixos-hardware.nixosModules.framework-amd-ai-300-series
            lanzaboote.nixosModules.lanzaboote
            ucodenix.nixosModules.default

            ./disks/tempest.nix
            ./hosts/tempest.nix

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                extraSpecialArgs = {
                  inherit inputs;
                  hostname = "tempest";
                };
                backupFileExtension = "backup";
                useGlobalPkgs = true;
                useUserPackages = true;

                users = {
                  irene = import ./homes/tempest.nix;
                  plasma = import ./homes/plasma.nix;
                };
              };
            }
          ];
        };

        vm = lib.nixosSystem {
          inherit system pkgs;
          specialArgs = {
            inherit inputs;
            hostname = "vm";
          };

          modules = [
            disko.nixosModules.disko
            impermanence.nixosModules.impermanence

            ./disks/vm.nix
            ./hosts/vm.nix

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                extraSpecialArgs = {
                  inherit inputs;
                  hostname = "vm";
                };
                backupFileExtension = "backup";
                useGlobalPkgs = true;
                useUserPackages = true;

                users = {
                  irene = import ./homes/vm.nix;
                };
              };
            }
          ];
        };
      };

      homeConfigurations = {
        "irene@orchid" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
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
