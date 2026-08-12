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
      # Do NOT override nixpkgs — upstream's lantian attic cache only has
      # store paths built against its pinned nixpkgs. Following ours forces
      # a full local kernel rebuild on every change.
      #
      # Note this is necessary but not sufficient: we apply `overlays.default`
      # below, which builds cachyosKernels against *our* nixpkgs, so the
      # derivation hash differs from the one upstream's Hydra pushed.
      # Measured 2026-08-09 for linux-cachyos-lts-lto-zen4-6.18.40: default →
      # g2b5i1w3848vc4cy4psmc6359z0zjkcp, pinned →
      # 03zf59q4mb1fgczynkf454x1lkbdy22a, and the attic serves a narinfo for
      # both (a well-formed but absent hash 404s, so those hits are real).
      # So there is no problem today — but it is luck, not a guarantee. If a
      # rebuild ever starts compiling a ThinLTO kernel locally, the fix is
      # `overlays.pinned`, which upstream recommends precisely for this. The
      # tradeoff there: cachyosKernels (and with it zfs_cachyos and any
      # extraModulePackages taken from that set) would come from upstream's
      # nixpkgs revision rather than ours.
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
      # Do NOT `follows = "nixpkgs"`, and do NOT leave this unpinned either.
      #
      # niri.cachix.org (added to the substituters by niri.nixosModules.niri
      # itself, which is why it isn't in modules/nix.nix) only holds
      # `niri.packages.*` as built by upstream CI — i.e. against the exact
      # nixpkgs in niri-flake's own flake.lock. Following our nixpkgs changes the
      # derivation hash and turns niri into a ~277 MB local Rust build.
      #
      # Merely dropping the `follows` is not enough: nix then reuses whatever
      # `github:NixOS/nixpkgs/nixos-unstable` node our lock already has, which
      # runs ahead of CI. That breaks the build outright, because niri-flake's
      # `make-niri` asserts `libdisplay-info_0_2.version == "0.2.0"` for both
      # niri-stable and niri-unstable, and nixpkgs removed the
      # libdisplay-info_0_2 alias on 2026-08-04.
      #
      # So pin it to niri-flake's own locked rev. Re-sync this whenever the niri
      # input is bumped (read `nixpkgs` out of niri-flake's flake.lock); if it
      # drifts you lose every cache hit, and if it drifts past a nixpkgs that
      # dropped libdisplay-info_0_2 the build fails loudly rather than silently.
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/e72e4f299401a3689d4b3d5fc6496b11db7064eb";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      # Do NOT add `inputs.nixpkgs.follows = "nixpkgs"`. Noctalia's Cachix
      # (noctalia.cachix.org, wired into modules/nix.nix on tempest) only has
      # paths built against the flake's own pinned nixpkgs; following ours would
      # invalidate every hit and force a full local Quickshell rebuild. See
      # https://docs.noctalia.dev/v5/getting-started/nixos/#binary-cache
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #rose-pine-hyprcursor = {
    #url = "github:ndom91/rose-pine-hyprcursor";
    #inputs.nixpkgs.follows = "nixpkgs";
    #inputs.hyprlang.follows = "hyprland/hyprlang";
    #};
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
    hn-tui-flake = {
      url = "github:asdrubalinea/hn-tui-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code.url = "github:sadjow/claude-code-nix";
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      # Numtide's AI-agent package set (ex nix-ai-tools); source for codex and
      # rtk, both of which nixpkgs ships well behind upstream. HM-only, so
      # update-home bumps it. Same reasoning as noctalia above:
      # do NOT add `inputs.nixpkgs.follows = "nixpkgs"`. cache.numtide.com (wired
      # into modules/nix.nix) only has paths built against the flake's own pinned
      # nixpkgs-unstable, and codex is a full Rust + rusty_v8 build locally.
    };
    drift = {
      url = "github:phlx0/drift";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    warp = {
      url = "github:warpdotdev/warp";
      # Warp's client is AGPL/MIT open source and the repo ships its own flake,
      # so build `warp-oss` from source rather than using nixpkgs' unfree
      # prebuilt tarball. app/src/bin/oss.rs constructs the OSS ChannelState
      # with `autoupdate_config: None`, so the "new version available but Warp
      # is unable to perform the update" banner the prebuilt build raises on
      # every launch cannot fire — no wrapper or pinned channel_versions.json
      # needed. It also passes `telemetry_config: None` and
      # `crash_reporting_config: None`, dropping the RudderStack and Sentry
      # wiring the prebuilt build ships with.
      #
      # Upstream labels the flake experimental and Linux-only, and it's a large
      # from-source Rust build with no published substituter — expect long
      # rebuilds whenever this input moves.
      #
      # Same reasoning as noctalia and llm-agents below: do NOT add
      # `inputs.nixpkgs.follows = "nixpkgs"`. It pins its own nixpkgs alongside
      # crane and rust-overlay against rust-toolchain.toml, and that pin is the
      # combination upstream actually builds against.
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

    # Steel plugin language is not a default cargo feature
    # (helix-term: `default = ["git"]`), so enable it here. The fork's
    # default.nix vendors deps via cargoLock + allowBuiltinFetchGit, so adding
    # a build feature needs no hash change. Note: buildRustPackage reads the
    # `cargoBuildFeatures` env var (mapped from its `buildFeatures` arg *inside*
    # the function), so overriding `buildFeatures` here would be ignored — we
    # must set `cargoBuildFeatures` directly via overrideAttrs.
    helixSteelOverlay = final: prev: {
      helix =
        (inputs.helix.packages.${final.stdenv.hostPlatform.system}.default).overrideAttrs
        (old: {
          cargoBuildFeatures = (old.cargoBuildFeatures or []) ++ ["steel"];
        });
    };

    # nixpkgs' python3Packages.pandas-stubs fails to build against pytest 9.1:
    # pytest now warns (PytestRemovedIn10Warning) on the generators upstream
    # passes to @parametrize, and pandas-stubs' `-W error` config makes that
    # fatal during collection. It reaches this closure as a *check* input of
    # pdfplumber, which markitdown propagates — see the python3 env in
    # desktop/home-packages.nix — so the whole HM generation dies on a type-stub
    # test suite. Same fix as the pending upstream PR: run those tests under
    # pytest 9.0. Note doCheck = false is NOT an option here — pandas-stubs sets
    # `pythonImportsCheck = [ "pandas" ]` and pandas comes in via
    # nativeCheckInputs, so skipping checks starves the import check instead.
    # Drop this overlay once https://github.com/NixOS/nixpkgs/pull/545267
    # reaches nixos-unstable.
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

    # Take the niri package set from niri-flake's `packages` output rather than
    # the attrs its overlay defines. The two are not the same build:
    # `overlays.niri = final: prev: make-package-set final` compiles against
    # whatever pkgs it lands in (ours), while `packages` uses the flake's own
    # nixpkgs — and only the latter is in niri.cachix.org. Ordered after
    # niri.overlays.niri so these aliases win.
    #
    # This also retires the libdisplay-info_0_2 backfill this overlay used to
    # carry: nothing builds niri against our nixpkgs any more, so the alias
    # unstable dropped is no longer needed. niri >= v25.11 wants 0.3 regardless.
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
      claude-code.overlays.default
      # `default` builds against our nixpkgs; `pinned` would use upstream's own
      # revision to guarantee attic cache hits. See the input's comment above
      # before changing this.
      nix-cachyos-kernel.overlays.default
    ];

    nixpkgsConfig = {
      allowUnfree = true;
      # rocmSupport = true;
      # pnpm is pulled in transitively (build-time dep of a Node-based tool in
      # the HM closure). nixpkgs marks old pnpm point releases insecure the
      # moment a newer one lands; bump this string when the next flake update
      # trips the same gate (error names the exact `pnpm-X.Y.Z`).
      permittedInsecurePackages = ["pnpm-10.34.0"];
    };

    mkPkgs = args:
      import nixpkgs ({
          system = defaultSystem;
          config = nixpkgsConfig;
          overlays = overlays;
        }
        // args);

    # Same shape as mkPkgs but built from the independent nixpkgs-home input,
    # so tempest's standalone home generation can be bumped without touching
    # the system channel. The stable/trunk/custom overlays continue to pull
    # from their own inputs, so `pkgs.stable.foo` still works.
    mkHomePkgs = args:
      import nixpkgs-home ({
          system = defaultSystem;
          config = nixpkgsConfig;
          overlays = overlays;
        }
        // args);

    lib = nixpkgs.lib;

    # tempest is defined once and instantiated twice: the real Framework laptop
    # (virtual = false) and an ephemeral QEMU clone (virtual = true). The
    # `virtual` specialArg is consumed by ./hosts/tempest/default.nix, which
    # conditionally imports the physical-machine layer (disko/zfs/impermanence/
    # lanzaboote/framework hardware) only when false, and ./hosts/tempest/vm.nix
    # only when true. Both share the exact same portable config — no duplicate
    # host to maintain. Build the VM with the ./build-vm script (or directly:
    # `nix build .#nixosConfigurations.tempest-vm.config.system.build.vmWithDisko`),
    # then run ./result/bin/disko-vm. NOT `nixos-rebuild build-vm`: that builds
    # the generic `system.build.vm`, which ignores the disko disk layout AND all
    # of vm.nix's `disko.tests.extraConfig` tuning (RAM/cores/GPU/neededForBoot).
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
  in {
    # Expose the locked home-manager CLI so it can be bootstrapped without
    # relying on whatever's in PATH — useful right after an `nh os switch` that
    # tears down /etc/profiles/per-user/irene before the first standalone HM
    # activation:
    #   nix run /persist/source-of-truth#home-manager -- switch \
    #     --flake '.#irene@tempest' -b backup
    packages.${defaultSystem}.home-manager =
      home-manager.packages.${defaultSystem}.default;

    nixosConfigurations = {
      "orchid" = lib.nixosSystem {
        specialArgs = {
          inherit inputs;
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
          niri.nixosModules.niri

          ./hosts/orchid/default.nix
        ];
      };

      # Real Framework laptop. Physical-machine modules (disko/impermanence/
      # lanzaboote/framework/ucodenix + ./disks/tempest.nix) are imported inside
      # ./hosts/tempest/default.nix, gated on the `virtual` specialArg.
      tempest = mkTempest false;

      # Ephemeral QEMU clone of tempest — same config, none of the physical
      # layer. Build with ./build-vm (→ system.build.vmWithDisko), run
      # ./result/bin/disko-vm. See mkTempest above for why not `nixos-rebuild build-vm`.
      tempest-vm = mkTempest true;

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
      # emulation and flashed as an SD image — no installer, no disko. The
      # boot/kernel stack (mainline generic sd-image, no nixos-hardware) is
      # imported inside ./hosts/zephyr/default.nix. See docs/adr/0005.
      zephyr = lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          hostname = "zephyr";
        };

        modules = [
          {
            # Trimmed overlay set: the desktop overlays
            # (niri/emacs/claude-code/cachyos) are irrelevant to a headless
            # ARM base and several don't build cleanly cross-arch.
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
          hyprland.homeManagerModules.default
          vscode-server.homeModules.default
          niri.homeModules.config
          stylix.homeModules.stylix

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
          # hyprland + stylix HM modules are imported inside homes/tempest.
          # niri.homeModules.config has to be added here because in the previous
          # nixos-module form it was auto-wired by niri.nixosModules.niri; in
          # standalone HM it has to be imported explicitly so programs.niri.*
          # options exist.
          niri.homeModules.config

          ./homes/tempest
        ];
      };
    };
  };
}
