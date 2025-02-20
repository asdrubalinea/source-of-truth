{
  description = "NixOS configurations for asdrubalinea 🏳️‍⚧️";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.05";
    nixpkgs-trunk.url = "github:nixos/nixpkgs";

    # nixpkgs-custom.url = "path:/persist/src/nixpkgs";
    nixpkgs-custom.url = "github:nixos/nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland";

    vscode-server.url = "github:nix-community/nixos-vscode-server";
  };

  outputs = inputs @ {
    nixpkgs,
    nixpkgs-stable,
    nixpkgs-trunk,
    nixpkgs-custom,
    home-manager,
    hyprland,
    vscode-server,
    ...
  }: let
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
  in {
    nixosConfigurations = {
      "orchid" = lib.nixosSystem {
        inherit system pkgs;

        specialArgs = { inherit inputs; }; # this is the important part (for hyprland)

        modules = [
          ./hosts/orchid.nix
        ];
      };
    };

    homeConfigurations = {
      "irene@orchid" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          ./homes/orchid.nix
          hyprland.homeManagerModules.default
          vscode-server.homeModules.default

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
