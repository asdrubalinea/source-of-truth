{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
stdenvNoCC.mkDerivation {
  pname = "ioskeley-mono";
  version = "2.0.0";

  src = fetchurl {
    url = "https://github.com/ahatem/IoskeleyMono/releases/download/v2.0.0/IoskeleyMono.zip";
    hash = "sha256-3Dd2P7uCy7mWEZVe4xlsd0wWTHFsD2WbS92+PTcMMgQ=";
  };

  nativeBuildInputs = [ unzip ];

  unpackPhase = ''
    runHook preUnpack
    unzip -q $src
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    find . -type f -path '*/Hinted/*.ttf' \
      -exec install -Dm644 -t $out/share/fonts/truetype/ioskeley-mono {} +
    runHook postInstall
  '';

  meta = with lib; {
    description = "Iosevka configuration crafted to mimic Berkeley Mono";
    homepage = "https://github.com/ahatem/IoskeleyMono";
    license = licenses.ofl;
    platforms = platforms.all;
  };
}
