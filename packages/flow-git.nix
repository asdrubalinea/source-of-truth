# Flow Control from master. nixpkgs tracks releases (0.7.2, zig 0.15) and
# master has moved to zig 0.16, so the source and the toolchain both move here.
#
# Two things can't be reached with a plain attribute override:
#   - zigDeps, because the nixpkgs one is bound to zig_0_15 in that file's own
#     `let`, so it's rebuilt against zig_0_16 instead;
#   - the dependency handoff, because 0.16 populates its cache with tarballs
#     rather than unpacked trees — `--system` no longer finds them, so the deps
#     are copied into ZIG_GLOBAL_CACHE_DIR/p the way nixpkgs' other zig 0.16
#     packages do.
# `fetchAll` stays off deliberately: it drags in nightwatch's macOS-only
# xcode-frameworks from code.hexops.org, which refuses connections.
{
  flow-control,
  fetchFromGitHub,
  zig_0_16,
}:
flow-control.overrideAttrs (final: _prev: {
  version = "0.7.2-unstable-2026-09-15";

  src = fetchFromGitHub {
    owner = "neurocyte";
    repo = "flow";
    rev = "35c7c2c48a3cb368ecc62d73a2869fb6b51ed33a";
    hash = "sha256-TmoxB1waGOsP85sCaLo86fMKNbCNO5IeD9dlXSHmvPk=";
  };

  zigDeps = zig_0_16.fetchDeps {
    inherit (final) src pname version;
    hash = "sha256-xHA3onrDxBNTc/rFZUorcy+B7QFSoyVCtQJtL9VaYeA=";
  };

  nativeBuildInputs = [zig_0_16];

  postConfigure = ''
    cp -rLT ${final.zigDeps} "$ZIG_GLOBAL_CACHE_DIR/p"
    chmod -R u+w "$ZIG_GLOBAL_CACHE_DIR/p"
  '';

  zigBuildFlags = [
    "-Dcpu=baseline"
    "-Doptimize=ReleaseFast"
  ];
})
