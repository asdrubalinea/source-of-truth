{ lib
, stdenv
, fetchFromGitHub
, pkg-config
, libusb1
, ncurses
, sdrplay
, rtl-sdr
}:

stdenv.mkDerivation rec {
  pname = "dump1090";
  version = "e320bd526c7abef33a69505bf12beefddf294dd4";

  src = fetchFromGitHub {
    owner = "SDRplay";
    repo = pname;
    rev = version;
    sha256 = "sha256-ArvMegJ+W0Y/bVm5llsh7rWwjOrodYbKuYYlM95Xv9c=";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libusb1 ncurses sdrplay rtl-sdr ];

  NIX_CFLAGS_COMPILE = lib.optionalString stdenv.cc.isClang
    "-Wno-implicit-function-declaration -Wno-int-conversion";

  buildFlags = [ "dump1090" "view1090" ];

  doCheck = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share
    cp -v dump1090 view1090 $out/bin
    cp -vr public_html $out/share/dump1090

    runHook postInstall
  '';

  meta = with lib; {
    description = "Version of dump1090 for RSP devices";
    homepage = "https://github.com/SDRplay/dump1090";
    license = licenses.gpl2Plus;
    platforms = platforms.unix;
    maintainers = with maintainers; [ earldouglas ];
  };
}
