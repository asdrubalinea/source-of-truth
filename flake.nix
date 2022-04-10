{
  description = "NixOS configurations for Asdrubalini";

  inputs = {
    nixpkgs.url =
      "github:nixos/nixpkgs/42948b300670223ca8286aaf916bc381f66a5313"; # Pinned from nixos-unstable
    home-manager.url =
      "github:nix-community/home-manager/f911ebbec927e8e9b582f2e32e2b35f730074cfc";
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
