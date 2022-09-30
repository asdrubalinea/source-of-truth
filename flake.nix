{
  description = "NixOS configurations for Asdrubalini";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-22.05";
    nixpkgs-trunk.url = "github:nixos/nixpkgs";

    # nixpkgs-custom.url = "path:/persist/src/nixpkgs";
    nixpkgs-custom.url = "github:asdrubalini/nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, nixpkgs-trunk, nixpkgs-custom, home-manager, ... }:
    let
      system = "x86_64-linux";
      username = "giovanni";

      multiChannelOverlay = final: prev: {
        stable = import nixpkgs-stable { system = final.system; config = final.config; };
        trunk = import nixpkgs-trunk { system = final.system; config = final.config; };
        custom = import nixpkgs-custom { system = final.system; config = final.config; };
      };

      pkgs = import nixpkgs {
        inherit system;
        config = { allowUnfree = true; };
        overlays = [ multiChannelOverlay ];
      };

      lib = nixpkgs.lib;
    in
    {
      nixosConfigurations = {
        swan = lib.nixosSystem {
          inherit system pkgs;

          modules = [ ./hosts/swan.nix ];
        };

        arrow = lib.nixosSystem {
          inherit system pkgs;

          modules = [ ./hosts/arrow.nix ];
        };

        test = lib.nixosSystem {
          inherit system pkgs;

          modules = [ ./containers/test.nix ];
        };
      };

      homeConfigurations = {
        giovanni-swan =
          home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              ./homes/swan.nix
              {
                home = {
                  username = "giovanni";
                  homeDirectory = "/home/${username}";
                  stateVersion = "22.05";
                };
              }
            ];
          };

        giovanni-arrow =
          home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              ./homes/arrow.nix
              {
                home = {
                  username = "giovanni";
                  homeDirectory = "/home/${username}";
                  stateVersion = "22.05";
                };
              }
            ];
          };

      };

    };
}
