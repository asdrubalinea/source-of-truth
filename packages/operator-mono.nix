{ lib, stdenv, requireFile, unzip }:

stdenv.mkDerivation rec {
  name = "OperatorMono";

  src = requireFile {
    name = "operator-mono.zip";
    sha256 = "b8fe53d2223ba40017b01c828e281a84ca86003dd91521b206e853bb8fb7ffb8";
    url = "https://github.com/";
  };

  # Unpack zip
  unpackCmd = ''${unzip}/bin/unzip "$src"'';

  installPhase = ''
    mkdir -p $out/share/fonts/opentype
    install -Dm444 -t $out/share/fonts/opentype Fonts/*.otf
  '';

  meta = with lib; {
    description = "Cool font";
    platforms = platforms.all;
  };
}

