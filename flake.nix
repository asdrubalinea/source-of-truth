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
      # Make home-manager use the same nixpkgs as the system
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko"; # Using default branch (often main/master)
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs"; # Good practice to follow the main nixpkgs
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
    rose-pine-hyprcursor = {
      url = "github:ndom91/rose-pine-hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.hyprlang.follows = "hyprland/hyprlang";
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
  };

  outputs =
    inputs @ { nixpkgs
    , nixpkgs-stable
    , nixpkgs-trunk
    , nixpkgs-custom
    , home-manager
    , hyprland
    , niri
    , vscode-server
    , disko
    , stylix
    , sops-nix
    , ...
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

        overlays = [ multiChannelOverlay ];
      };

      lib = nixpkgs.lib;
    in
    {
      nixosConfigurations = {
        "orchid" = lib.nixosSystem {
          inherit system pkgs;
          specialArgs = { inherit inputs; };

          modules = [
            niri.nixosModules.niri

            ./hosts/orchid.nix
          ];
        };

        "tempest" = lib.nixosSystem {
          inherit system pkgs;
          specialArgs = { inherit inputs; };

          modules = [
            disko.nixosModules.disko

            ./hosts/tempest.nix
            ./disks/tempest.nix
          ];
        };
      };

      homeConfigurations = {
        "irene@orchid" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit inputs; };

          modules = [
            hyprland.homeManagerModules.default
            vscode-server.homeModules.default
            niri.homeModules.config
            stylix.homeManagerModules.stylix

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
