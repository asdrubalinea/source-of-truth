{
  description = "NixOS configurations for Asdrubalini";

  inputs = {
    nixpkgs.url =
      "github:nixos/nixpkgs/bc4b9eef3ce3d5a90d8693e8367c9cbfc9fc1e13";
    home-manager.url =
      "github:nix-community/home-manager/07b941f0c45ac4af6732d96f4cb6142824eee3df";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      username = "giovanni";
      pkgs = import nixpkgs {
        inherit system;
        config = { allowUnfree = true; };
      };

      lib = nixpkgs.lib;
    in {
      nixosConfigurations = {
        swan = lib.nixosSystem {
          inherit system;

          modules = [ ./hosts/swan.nix ];
        };

        staff = lib.nixosSystem {
          inherit system;

          modules = [ ./hosts/staff.nix ];
        };
      };

      homeConfigurations.${username} =
        home-manager.lib.homeManagerConfiguration {
          configuration = import ./homes/swan.nix;

          inherit system pkgs username;
          homeDirectory = "/home/${username}";
          stateVersion = "22.05";
        };
    };
}
