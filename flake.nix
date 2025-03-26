{
  description = "NixOS configurations for asdrubalinea 🏳️‍⚧️";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-trunk.url = "github:nixos/nixpkgs";

    # nixpkgs-custom.url = "path:/persist/src/nixpkgs";
    nixpkgs-custom.url = "github:nixos/nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland";
    hyprtasking = {
      url = "github:raybbian/hyprtasking";
      inputs.hyprland.follows = "hyprland";
    };
    vscode-server.url = "github:nix-community/nixos-vscode-server";

    niri.url = "github:sodiboo/niri-flake";

    # operator-mono.url = "path:/persist/Operator-Mono";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    rose-pine-hyprcursor = {
      url = "github:ndom91/rose-pine-hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.hyprlang.follows = "hyprland/hyprlang";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix.url = "github:danth/stylix";
    sops-nix.url = "github:Mic92/sops-nix";

    # mm.url = "github:asdrubalinea/mm-schema";
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
