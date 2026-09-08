{
  description = "NixOS configurations for asdrubalinea 🏳️‍⚧️";

  inputs = {
    # --- Nixpkgs Channels ---
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Separate unstable input so tempest's standalone home build can be advanced
    # independently of the system channel (nix flake update nixpkgs-home).
    nixpkgs-home.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-trunk.url = "github:nixos/nixpkgs";
    nixpkgs-custom.url = "github:nixos/nixpkgs";

    # --- Core Components ---
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ucodenix.url = "github:e-tho/ucodenix";
    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel/release";
      # No `follows`: upstream's attic cache only holds paths built against its
      # own nixpkgs pin. If a rebuild ever starts compiling a kernel locally,
      # switch the overlay below to `overlays.pinned`.
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
      # Pinned to niri-flake's OWN locked nixpkgs rev — not `follows`, not
      # unpinned. niri.cachix.org only holds packages built against that exact
      # rev; anything else is a ~277 MB local Rust build (or an outright eval
      # failure on the libdisplay-info_0_2 assert). Re-sync this whenever the
      # niri input is bumped: read `nixpkgs` out of niri-flake's flake.lock.
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/e72e4f299401a3689d4b3d5fc6496b11db7064eb";
    };
    mangowm = {
      url = "github:mangowm/mango";
      # `follows` is right here, unlike niri: no upstream cache to miss either
      # way, and it's a small C build. Carries nixosModules.mango + hmModules.mango
      # (ADR 0012).
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      # No `follows`: noctalia.cachix.org only has paths built against its own
      # nixpkgs pin, and the fallback is a full local Quickshell build.
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
    anyrun = {
      url = "github:anyrun-org/anyrun";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- Applications/Services ---
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium-browser = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    diapee-bot = {
      url = "github:asdrubalinea/diapee-bot/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tribunale-scrape = {
      url = "github:asdrubalinea/tribunale-scrape";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    auxologico-check = {
      url = "github:asdrubalinea/auxologico-check";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flights = {
      url = "github:asdrubalinea/flights";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helix = {
      url = "github:mattwparas/helix/steel-event-system";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code.url = "github:sadjow/claude-code-nix";
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      # codex/rtk et al, tracked closer than nixpkgs does. HM-only (update-home
      # bumps it). No `follows` — same cache reasoning as noctalia; codex is a
      # full Rust + rusty_v8 build otherwise.
    };
    drift = {
      url = "github:phlx0/drift";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lights = {
      url = "github:asdrubalinea/lights";
      # No flake of its own, just the package.nix sitting beside its Cargo.lock,
      # which is all we need — see homes/tempest/lights.nix. HM-only, so
      # update-home bumps it.
      flake = false;
    };
    warp = {
      url = "github:warpdotdev/warp";
      # `warp-oss` from source instead of nixpkgs' unfree prebuilt: the OSS
      # binary passes autoupdate/telemetry/crash-reporting config as None, so
      # there's no update nag and no RudderStack/Sentry. No `follows` — it pins
      # nixpkgs + crane + rust-overlay against its own rust-toolchain.toml.
      # No substituter, so expect a long rebuild whenever this moves.
    };
    openlogi = {
      # Pinned to a rev, not a tag: nixpkgs' 0.6.25 can't see tempest's
      # Lightspeed receiver, v0.7.1 doesn't build, and master panics at startup
      # when a camera is present. 822c6e41 is the last good commit. Bump
      # deliberately and check `openlogi list` + a GUI launch afterwards.
      # From-source gpui build, no substituter — slow rebuilds.
      url = "github:AprilNEA/OpenLogi/822c6e4181f0118713473bcc524e6a7fbd51f5a4";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
  };

  outputs = inputs @ {
    nixpkgs,
    nixpkgs-home,
    nixpkgs-stable,
    nixpkgs-trunk,
    nixpkgs-custom,
    home-manager,
    hyprland,
    niri,
    vscode-server,
    disko,
    impermanence,
    stylix,
    sops-nix,
    nixos-hardware,
    emacs-overlay,
    lanzaboote,
    ucodenix,
    claude-code,
    nix-cachyos-kernel,
    ...
  }: let
    defaultSystem = "x86_64-linux";

    multiChannelOverlay = final: prev: {
      stable = import nixpkgs-stable {
        system = final.stdenv.hostPlatform.system;
        config = final.config;
      };

      trunk = import nixpkgs-trunk {
        system = final.stdenv.hostPlatform.system;
        config = final.config;
      };

      custom = import nixpkgs-custom {
        system = final.stdenv.hostPlatform.system;
        config = final.config;
      };
    };

    # Steel plugin support isn't a default cargo feature, so turn it on. It has
    # to be `cargoBuildFeatures` and not `buildFeatures`: buildRustPackage maps
    # the latter internally, so an overrideAttrs on it is ignored.
    helixSteelOverlay = final: prev: {
      helix =
        (inputs.helix.packages.${final.stdenv.hostPlatform.system}.default).overrideAttrs
        (old: {
          cargoBuildFeatures = (old.cargoBuildFeatures or []) ++ ["steel"];
        });
    };

    # pandas-stubs' test suite is fatal-on-warning and pytest 9.1 warns on it,
    # which kills the whole HM generation (it arrives as a check input of
    # pdfplumber ← markitdown). Run those tests under pytest 9.0, as the pending
    # upstream fix does. `doCheck = false` does not work — it starves
    # pythonImportsCheck instead. Drop once nixpkgs#545267 lands.
    pandasStubsOverlay = final: prev: {
      pythonPackagesExtensions =
        prev.pythonPackagesExtensions
        ++ [
          (pyfinal: pyprev: {
            pandas-stubs = pyprev.pandas-stubs.overridePythonAttrs (old: {
              nativeCheckInputs =
                (prev.lib.remove pyfinal.pytestCheckHook old.nativeCheckInputs)
                ++ [pyfinal.pytest9_0CheckHook];
            });
          })
        ];
    };

    # Use niri-flake's `packages` output, not the attrs its overlay defines:
    # the overlay rebuilds against our pkgs, `packages` is what's in
    # niri.cachix.org. Must be ordered after niri.overlays.niri so these win.
    niriPrebuiltOverlay = final: _prev: let
      inherit (final.stdenv.hostPlatform) system;
    in {
      inherit
        (niri.packages.${system})
        niri-stable
        niri-unstable
        xwayland-satellite-stable
        xwayland-satellite-unstable
        ;
    };

    overlays = [
      multiChannelOverlay
      helixSteelOverlay
      pandasStubsOverlay
      emacs-overlay.overlay
      niri.overlays.niri
      niriPrebuiltOverlay
      # `pkgs.mango`, so the session, the HM validator and swayidle's `mmsg`
      # call all agree on one derivation.
      inputs.mangowm.overlays.default
      # Unfixed upstream: mango cleared only_sleep on every head of every client
      # config, so kanshi churn (the bus-powered panel dropping off on sleep)
      # ejected the slept QD-OLED from the layout for good — black panel until
      # the compositor died. Patch clears it only on a commit that enables the
      # head. See docs/mango-vs-niri.md.
      (final: prev: {
        mango = prev.mango.overrideAttrs (old: {
          patches = (old.patches or []) ++ [./packages/patches/mango-outputmgr-keeps-only-sleep.patch];
        });
      })
      # ./build-vm fix: disko hands vmTools a targetless `aggregateModules`
      # kernel, and nixpkgs' vmTools now throws on that. Supply the platform's
      # kernel image filename, only for that case. Delete once disko passes
      # kernelImage itself (still not fixed as of its locked HEAD).
      (final: prev: {
        vmTools =
          prev.vmTools
          // {
            override = args:
              prev.vmTools.override (
                args
                // nixpkgs.lib.optionalAttrs (args ? kernel && !(args.kernel ? target)) {
                  kernelImage = final.linuxPackages.kernel.target;
                }
              );
          };
      })
      claude-code.overlays.default
      nix-cachyos-kernel.overlays.default
    ];

    nixpkgsConfig = {
      allowUnfree = true;
      # Transitive dep; nixpkgs marks old pnpm point releases insecure as soon
      # as a newer one lands. Bump when a flake update names a new pnpm-X.Y.Z.
      permittedInsecurePackages = ["pnpm-10.34.0"];
    };

    mkPkgs = args:
      import nixpkgs ({
          system = defaultSystem;
          config = nixpkgsConfig;
          overlays = overlays;
        }
        // args);

    # mkPkgs off the independent nixpkgs-home input, so tempest's HM generation
    # can be bumped without touching the system channel.
    mkHomePkgs = args:
      import nixpkgs-home ({
          system = defaultSystem;
          config = nixpkgsConfig;
          overlays = overlays;
        }
        // args);

    lib = nixpkgs.lib;

    # One definition, two instances: the real laptop (virtual = false) and an
    # ephemeral QEMU clone (true). hosts/tempest/default.nix reads the
    # `virtual` specialArg to swap the physical-hardware layer for ./vm.nix.
    # Build the clone with `./build-vm tempest`, never `nixos-rebuild build-vm`
    # — that ignores the disko layout and vm.nix's tuning.
    mkTempest = virtual:
      lib.nixosSystem {
        specialArgs = {
          inherit inputs virtual;
          hostname = "tempest";
        };

        modules = [
          {
            nixpkgs = {
              hostPlatform = defaultSystem;
              config = nixpkgsConfig;
              overlays = overlays;
            };
          }
          niri.nixosModules.niri

          ./hosts/tempest/default.nix
        ];
      };

    # Same trick for orchid. There's no physical layer to gate off here, so
    # `virtual` only adds ./vm.nix's guest sizing. `./build-vm orchid`.
    mkOrchid = virtual:
      lib.nixosSystem {
        specialArgs = {
          inherit inputs virtual;
          hostname = "orchid";
        };

        modules = [
          {
            nixpkgs = {
              hostPlatform = defaultSystem;
              config = nixpkgsConfig;
              overlays = overlays;
            };
          }

          # Headless for now, so no compositor module. disko + impermanence are
          # imported inside the host, as tempest does it.
          ./hosts/orchid/default.nix
        ];
      };
  in {
    # The locked HM CLI, for bootstrapping when it isn't on PATH yet:
    #   nix run /persist/source-of-truth#home-manager -- switch \
    #     --flake '.#irene@tempest' -b backup
    packages.${defaultSystem}.home-manager =
      home-manager.packages.${defaultSystem}.default;

    nixosConfigurations = {
      # Real tower, and its ephemeral QEMU clone (see mkOrchid).
      orchid = mkOrchid false;
      orchid-vm = mkOrchid true;

      # Real Framework laptop, and its ephemeral QEMU clone (see mkTempest).
      tempest = mkTempest false;
      tempest-vm = mkTempest true;

      # The per-project dev VM (docs/adr/0013). NOT a host clone: one image
      # serves every ocelot, with project path / state disk / ssh port / name
      # handed over at boot by scripts/ocelot.sh, the only thing that builds
      # this. HM is a NixOS module here — a guest rebuilt every boot has no
      # second activation step.
      ocelot = lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          hostname = "ocelot";
        };

        modules = [
          {
            nixpkgs = {
              hostPlatform = defaultSystem;
              config = nixpkgsConfig;
              overlays = overlays;
            };
          }
          impermanence.nixosModules.impermanence
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = {
                inherit inputs;
                hostname = "ocelot";
              };
              users.irene.imports = [./homes/ocelot.nix];
              backupFileExtension = "hm-bak";
            };
          }

          ./hosts/ocelot/default.nix
        ];
      };

      hydra = lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          hostname = "hydra";
        };

        modules = [
          {
            nixpkgs = {
              hostPlatform = defaultSystem;
              config = nixpkgsConfig;
              overlays = overlays;
            };
          }
          disko.nixosModules.disko

          ./disks/hydra.nix
          ./hosts/hydra/default.nix
        ];
      };

      # Raspberry Pi 3B+ (aarch64), headless. Built on tempest under binfmt
      # emulation and flashed as an SD image — no installer, no disko.
      # See docs/adr/0005.
      zephyr = lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          hostname = "zephyr";
        };

        modules = [
          {
            # Trimmed overlay set: the desktop overlays are irrelevant here and
            # several don't build cleanly cross-arch.
            nixpkgs = {
              hostPlatform = "aarch64-linux";
              config = nixpkgsConfig;
              overlays = [multiChannelOverlay];
            };
          }

          ./hosts/zephyr/default.nix
        ];
      };
    };

    homeConfigurations = {
      "irene@orchid" = home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgs {};
        extraSpecialArgs = {
          inherit inputs;
          hostname = "orchid";
        };

        modules = [
          # No compositor/theming modules — orchid has no WM for now. Re-add
          # them alongside the rice import in homes/orchid.nix.
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

      "irene@tempest" = home-manager.lib.homeManagerConfiguration {
        pkgs = mkHomePkgs {};
        extraSpecialArgs = {
          inherit inputs;
          hostname = "tempest";
        };

        modules = [
          # Needed explicitly under standalone HM (the NixOS module used to
          # auto-wire it) so programs.niri.* options exist. stylix is imported
          # inside homes/tempest.
          niri.homeModules.config

          ./homes/tempest
        ];
      };
    };
  };
}
