# OpenAI's ChatGPT desktop app (the Codex-based Electron build), repackaged from
# the upstream .deb. nixpkgs' `chatgpt` is the aarch64-darwin build only, hence
# this file. The src is pinned to the apt pool path rather than the documented
# `.../deb/latest/chatgpt_amd64.deb`, which moves under the hash every release;
# to bump, read Version/SHA256 from
#   https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages
#
# Native Wayland is "experimental" upstream (floating windows, positioning and
# global shortcuts may misbehave); the wrapper selects it whenever the session
# sets NIXOS_OZONE_WL, as both ember compositors do. Unset it for one launch
# (`env -u NIXOS_OZONE_WL chatgpt`) to fall back to XWayland.
#
# The main binary is patched so Node's process.report can't kill it: see
# installPhase.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  buildPackages,
  python3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libGL,
  libgbm,
  libnotify,
  libpulseaudio,
  libsecret,
  libusb1,
  libva,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  openssl,
  pango,
  pipewire,
  systemd,
  tpm2-tss,
  vulkan-loader,
  wayland,
  xdg-utils,
}:
stdenv.mkDerivation rec {
  pname = "chatgpt-linux";
  version = "26.1013.40934";

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
    hash = "sha256-PKWef5pmQbni+5rWgGg3hLWrgCb/dBj7ISoOvl3zodc=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    python3
    # The shell wrapper, not the default binary one: the Wayland flag below is a
    # ${VAR:+...} expansion that has to happen at launch.
    (buildPackages.wrapGAppsHook3.override {makeWrapper = buildPackages.makeShellWrapper;})
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libusb1
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    openssl
    pango
    stdenv.cc.cc.lib
    systemd # libudev
    tpm2-tss
  ];

  # dlopen()ed by Chromium at runtime, so autoPatchelf can't see them as NEEDED.
  runtimeDependencies = [
    libGL
    libnotify
    libpulseaudio
    libsecret
    (lib.getLib libva)
    pipewire
    systemd
    vulkan-loader
    wayland
  ];

  # The Qt shims are optional (Chromium only loads them under a Qt desktop and
  # otherwise uses GTK); pulling Qt5 and Qt6 in just to satisfy them isn't worth it.
  autoPatchelfIgnoreMissingDeps = ["libQt5*" "libQt6*"];

  dontWrapGApps = true;

  unpackPhase = ''
    dpkg-deb --fsys-tarfile $src | tar xf - --no-same-permissions --no-same-owner
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/bin
    cp -R usr/lib/chatgpt $out/lib/chatgpt
    cp -R usr/share $out/share
    rm -rf $out/share/{doc,lintian,swcatalog}

    # Native prebuilds for other platforms (arm, musl, android) ship alongside
    # the x64-glibc ones and would only fail autoPatchelf.
    find $out/lib/chatgpt/resources -type d \
      \( -name '*linux-arm*' -o -name '*-musl' -o -name 'android-*' \) -prune -exec rm -rf {} +
    find $out/lib/chatgpt/resources -name '*.musl.node' -delete
    rm $out/lib/chatgpt/libqt5_shim.so $out/lib/chatgpt/codex-launcher

    # process.report.getReport() looks up gnu_get_libc_version with
    # dlsym(RTLD_DEFAULT, ...) and calls the result. This build enforces
    # control-flow integrity on indirect calls, and a pointer into libc fails
    # the check, so the call traps (SIGILL) and kills the app. The bundled
    # detect-libc only gets there when /usr/bin/ldd is missing, which on NixOS
    # it always is, a few seconds into every launch. Renaming the .rodata
    # copy of the string (not the .dynstr import Chromium links against) makes
    # dlsym return NULL, and Node then skips the call; detect-libc falls back to
    # `getconf GNU_LIBC_VERSION`. This runs before fixup on purpose: patchelf
    # moves .dynstr, but leaves .rodata alone.
    python3 - $out/lib/chatgpt/ChatGPT <<'EOF'
    import struct, sys
    path = sys.argv[1]
    elf = bytearray(open(path, "rb").read())
    shoff, = struct.unpack_from("<Q", elf, 0x28)
    shentsize, shnum, shstrndx = struct.unpack_from("<HHH", elf, 0x3A)
    def section(i):
        return struct.unpack_from("<IIQQQQ", elf, shoff + i * shentsize)
    strtab_off = section(shstrndx)[4]
    for i in range(shnum):
        name, _, _, _, off, size = section(i)
        start = strtab_off + name
        if elf[start : elf.index(b"\0", start)] == b".rodata":
            break
    else:
        sys.exit("no .rodata section")
    old, new = b"\0gnu_get_libc_version\0", b"\0nix_get_libc_version\0"
    hits = elf.count(old, off, off + size)
    if hits != 1:
        sys.exit(f"expected one gnu_get_libc_version in .rodata, found {hits}")
    at = elf.index(old, off, off + size)
    elf[at : at + len(old)] = new
    open(path, "wb").write(elf)
    EOF

    install -Dm644 usr/share/pixmaps/chatgpt.png $out/share/icons/hicolor/1024x1024/apps/chatgpt.png

    # A chat client has no business offering itself as an http(s) handler.
    substituteInPlace $out/share/applications/chatgpt.desktop \
      --replace-fail 'x-scheme-handler/http;x-scheme-handler/https;' ""

    runHook postInstall
  '';

  # Same fix as mailspring in desktop/home-packages.nix: Electron can't infer a
  # password store under niri/mango, so name GNOME Keyring's Secret Service.
  postFixup = ''
    makeWrapper $out/lib/chatgpt/ChatGPT $out/bin/chatgpt \
      "''${gappsWrapperArgs[@]}" \
      --suffix PATH : ${lib.makeBinPath [xdg-utils]} \
      --add-flags "--password-store=gnome-libsecret" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
  '';

  meta = {
    description = "ChatGPT desktop app by OpenAI";
    homepage = "https://learn.chatgpt.com/docs/linux/linux-app";
    license = lib.licenses.unfree;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    platforms = ["x86_64-linux"];
    mainProgram = "chatgpt";
  };
}
