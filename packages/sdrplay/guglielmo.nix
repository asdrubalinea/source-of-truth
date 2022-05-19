{ lib
, stdenv
, fetchFromGitHub
, cmake
, pkg-config
, airspy
, librtlsdr
, fdk_aac
, faad2
, fftwFloat
, libsndfile
, libsamplerate
, portaudio
, libsForQt5
, sdrplay
}:

stdenv.mkDerivation rec {
  pname = "guglielmo";
  version = "ca7466d6df7151704d58e0e5e1cd04d4c6f02380";

  src = fetchFromGitHub {
    owner = "marcogrecopriolo";
    repo = pname;
    rev = version;
    sha256 = "sha256-201I1iIsYiepoc9HNEkkAHKtUfgwKwC/AiuSXFECT0w=";
  };

  postInstall = ''
    mv $out/linux-bin $out/bin
  '';

  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [
    libsForQt5.wrapQtAppsHook
    airspy
    librtlsdr
    fdk_aac
    faad2
    fftwFloat
    libsndfile
    libsamplerate
    portaudio
    libsForQt5.qtmultimedia
    libsForQt5.qwt
    sdrplay
  ];

  postFixup = ''
    # guglielmo opens SDR libraries at run time
    patchelf --add-rpath "${airspy}/lib:${librtlsdr}/lib:${sdrplay}/lib" $out/bin/.guglielmo-wrapped
  '';
}
