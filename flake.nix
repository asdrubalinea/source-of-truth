{
  description = "NixOS configurations for Asdrubalini";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-21.11";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    trunk.url = "github:nixos/nixpkgs";

    # nixpkgs.url = "path:/persist/src/nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "unstable";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      username = "giovanni";

      multiChannelOverlay = final: prev: {
        unstable = import inputs.unstable { system = final.system; config = final.config; };
        trunk = import inputs.trunk { system = final.system; config = final.config; };
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
          inherit system;

          modules = [ ./hosts/swan.nix ];
        };
      };

      homeConfigurations.giovanni-swan =
        home-manager.lib.homeManagerConfiguration {
          configuration = import ./homes/swan.nix;

          inherit system pkgs username;
          homeDirectory = "/home/${username}";
          stateVersion = "22.05";
        };
    };
}
