# LibrePods — control AirPods (noise-control modes, ear detection, battery,
# conversational awareness) from Linux by speaking Apple's proprietary AAP
# protocol over an L2CAP channel.
#
# Why this file instead of `pkgs.librepods`: nixpkgs ships v0.2.5, which is the
# OLD Qt6/QML app. Upstream has since rewritten the Linux client in Rust (iced +
# bluer + ksni), and that rewrite is what their README points users at — but it
# lives on the unmerged `linux/rust` branch (upstream PR #241, still draft) with
# no tag, distributed only as AppImages and CI artifacts. So we build the branch
# ourselves.
#
# Two consequences of taking the rewrite over nixpkgs':
#
#   - No privileges needed. The Rust client only ever connect()s its L2CAP
#     sockets, never bind()s, so it does not want the `cap_net_admin` file
#     capability that `programs.librepods` grants the Qt version — no
#     security.wrappers entry and no `librepods` group. Upstream's own Flatpak
#     manifest likewise runs unprivileged with just `--allow=bluetooth`. That is
#     why this is a plain home.packages entry with no system-side counterpart.
#   - It draws with iced/wgpu rather than Qt, so it is a GPU-compositing Wayland
#     client. If it flickers on redraw under niri, that is the explicit-sync bug
#     already documented for Chrome/Qt6 — not something specific to this app.
#
# Upstream does ship a crane-based flake.nix on that branch and it evaluates
# fine, but it is not used here: it would drag crane + flake-parts + treefmt-nix
# + its own December-2025 nixpkgs pin into our flake.lock (so no cache sharing
# with our rustc), and it installs nothing but the bare binary anyway — no
# desktop entry, no icon. Both problems disappear by just calling
# buildRustPackage against our own nixpkgs, which is what we do below.
#
# Bumping: set rev, then blank `hash` and `cargoHash` in turn and take the
# "got:" values Nix reports. Pinned deliberately rather than tracked as a flake
# input — this is an unmerged dev branch, and an unattended `nix flake update`
# that moved Cargo.lock would break `cargoHash` at rebuild time.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  pkg-config,
  alsa-lib,
  bluez,
  dbus,
  expat,
  fontconfig,
  freetype,
  libGL,
  libpulseaudio,
  libx11,
  libxcursor,
  libxi,
  libxkbcommon,
  libxrandr,
  vulkan-loader,
  wayland,
}:
let
  # iced 0.14 renders through wgpu and takes its window from winit; both dlopen
  # their backends at runtime instead of linking them, so these have to be on
  # LD_LIBRARY_PATH and not merely in buildInputs. List mirrors the buildInputs
  # of upstream's flake.nix, which wraps the binary the same way.
  runtimeLibs = [
    alsa-lib
    bluez
    dbus
    expat
    fontconfig
    freetype
    libGL
    libpulseaudio
    libx11
    libxcursor
    libxi
    libxkbcommon
    libxrandr
    vulkan-loader
    wayland
  ];
in
rustPlatform.buildRustPackage {
  pname = "librepods";
  # Cargo.toml says 0.1.0 and there is no tag on the branch, so date the rev.
  version = "0.1.0-unstable-2026-05-15";

  src = fetchFromGitHub {
    owner = "librepods-org";
    repo = "librepods";
    rev = "672e65ad36eebf21ff1c1a508066f9197ee56d17";
    hash = "sha256-EuIYvBqBtpgutVqPOLIO3E9OhVzQ5q5TDoz/F+9MHEE=";
  };

  # The monorepo holds the Android app and the old Qt client too; the rewrite is
  # its own crate under linux-rust/.
  sourceRoot = "source/linux-rust";

  cargoHash = "sha256-17dE+oYvECU4f1SL6LHS95sXEea/Z0VgTPQ4u6TZTic=";

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  buildInputs = runtimeLibs;

  # No test targets in the crate.
  doCheck = false;

  # cargoInstallHook only lands the binary. Upstream places the desktop entry
  # and icon from their AppImage Justfile, which we do not run, so do it here —
  # otherwise the app has no launcher entry and the tray/window fall back to a
  # missing-icon placeholder.
  postInstall = ''
    install -Dm644 assets/me.kavishdevar.librepods.desktop \
      $out/share/applications/me.kavishdevar.librepods.desktop
    install -Dm644 assets/icon.png \
      $out/share/icons/hicolor/256x256/apps/me.kavishdevar.librepods.png

    wrapProgram $out/bin/librepods \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
  '';

  meta = {
    description = "AirPods liberated from Apple's ecosystem (Rust rewrite)";
    homepage = "https://github.com/librepods-org/librepods";
    license = lib.licenses.gpl3Only;
    mainProgram = "librepods";
    platforms = lib.platforms.linux;
  };
}
