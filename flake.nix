{
  description = "NixOS configurations for Asdrubalini";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { nixpkgs, home-manager, rust-overlay, ... }:
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

          modules = [
            ./hosts/swan.nix

            # Rust
            ({ pkgs, ... }: {
              nixpkgs.overlays = [ rust-overlay.overlay ];
              environment.systemPackages = with pkgs; [
                rust-bin.stable.latest.default
                rust-analyzer
              ];
            })
          ];
        };

        staff = lib.nixosSystem {
          inherit system;

          modules = [ ./hosts/staff.nix ];
        };

        arrow = lib.nixosSystem {
          inherit system;

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
