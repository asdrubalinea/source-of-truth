{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  libGL,
  vulkan-loader,
  libX11,
  libXext,
  libXrandr,
  libxcb,
}:
# Prebuilt GPU benchmark. The .run is a makeself archive; its payload is a
# gzip tarball after the 567-line shell header. X11 only, so it runs under
# xwayland-satellite on niri/mango.
stdenv.mkDerivation rec {
  pname = "gravitymark";
  version = "1.89";

  src = fetchurl {
    url = "https://tellusim.com/download/GravityMark_${version}.run";
    hash = "sha256-3gkMe55A8Q8iXZOT8s9zpmCtTtwh9rMz7qMZCoci4AU=";
  };

  nativeBuildInputs = [autoPatchelfHook makeWrapper];
  buildInputs = [stdenv.cc.cc.lib libX11 libXext libXrandr libxcb];

  unpackPhase = ''
    tail -n +568 $src | tar xz
  '';

  # The launcher execs ./GravityMark.x64 next to itself and both read
  # ../{data,browser}.zip, so keep the upstream layout intact.
  # libTellusim dlopens unversioned libvulkan.so / libGL.so; RUNPATH on the
  # executable doesn't reach a library's dlopen, so pass them by env.
  installPhase = let
    wrap = "--chdir $out/share/gravitymark/bin --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [libGL vulkan-loader]}";
  in ''
    mkdir -p $out/share/gravitymark $out/bin
    cp -r bin data.zip browser.zip GravityMark_Manual.pdf $out/share/gravitymark/
    makeWrapper $out/share/gravitymark/bin/Browser.x64 $out/bin/gravitymark \
      ${wrap} --add-flags "-root browser/ ../browser.zip"
    makeWrapper $out/share/gravitymark/bin/GravityMark.x64 $out/bin/gravitymark-cli ${wrap}
  '';

  meta = {
    description = "GPU benchmark rendering huge object counts with Vulkan/OpenGL, incl. ray tracing";
    homepage = "https://gravitymark.tellusim.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    mainProgram = "gravitymark";
    platforms = ["x86_64-linux"];
  };
}
