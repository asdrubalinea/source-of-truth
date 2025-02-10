{
  description = "NixOS configurations for Asdrubalini";

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

  outputs = {
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
    username = "giovanni";

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
      overlays = [multiChannelOverlay];
    };

    trunkPkgs = import nixpkgs-trunk {
      inherit system;
      config = {allowUnfree = true;};
    };

    stablePkgs = import nixpkgs-stable {
      inherit system;
      config = {allowUnfree = true;};
    };

    lib = nixpkgs.lib;
  in {
    nixosConfigurations = {
      swan = lib.nixosSystem {
        inherit system pkgs;

        modules = [./hosts/swan.nix];
      };

      orchid = lib.nixosSystem {
        inherit system pkgs;

        modules = [
          ./hosts/orchid.nix
        ];
      };

      arrow = lib.nixosSystem {
        inherit system pkgs;

        modules = [./hosts/arrow.nix];
      };

      router = lib.nixosSystem {
        inherit system pkgs;

        modules = [./hosts/router.nix];
      };

      test = lib.nixosSystem {
        inherit system pkgs;

        modules = [./containers/test.nix];
      };

      docker = lib.nixosSystem {
        inherit system pkgs;

        modules = [./hosts/docker.nix];
      };
    };

    homeConfigurations = {
      giovanni-swan = home-manager.lib.homeManagerConfiguration {
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

      irene-orchid = home-manager.lib.homeManagerConfiguration {
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

      giovanni-arrow = home-manager.lib.homeManagerConfiguration {
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

      giovanni-router = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./homes/router.nix
          {
            home = {
              username = "giovanni";
              homeDirectory = "/home/${username}";
              stateVersion = "22.05";
            };
          }
        ];
      };

      giovanni-docker = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./homes/docker.nix
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
