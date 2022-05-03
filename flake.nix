{
  description = "NixOS configurations for Asdrubalini";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-21.11";
    nixpkgs-trunk.url = "github:nixos/nixpkgs";

    # nixpkgs.url = "path:/persist/src/nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, nixpkgs-trunk, home-manager, ... }:
    let
      system = "x86_64-linux";
      username = "giovanni";

      multiChannelOverlay = final: prev: {
        stable = import nixpkgs-stable { system = final.system; config = final.config; };
        trunk = import nixpkgs-trunk { system = final.system; config = final.config; };
      };

      pkgs = import nixpkgs {
        inherit system;
        config = { allowUnfree = true; };
        overlays = [ multiChannelOverlay ];
      };

      lib = nixpkgs.lib;
    in {
      nixosConfigurations = {
        swan = lib.nixosSystem {
          inherit system pkgs;

          modules = [ ./hosts/swan.nix ];
        };

        arrow = lib.nixosSystem {
          inherit system pkgs;

          modules = [ ./hosts/arrow.nix ];
        };
      };

      homeConfigurations.giovanni-swan =
        home-manager.lib.homeManagerConfiguration {
          configuration = import ./homes/swan.nix;

          inherit system pkgs username;
          homeDirectory = "/home/${username}";
          stateVersion = "22.05";
        };

      homeConfigurations.giovanni-arrow =
        home-manager.lib.homeManagerConfiguration {
          configuration = import ./homes/arrow.nix;

          inherit system pkgs username;
          homeDirectory = "/home/${username}";
          stateVersion = "22.05";
        };
    };
}
