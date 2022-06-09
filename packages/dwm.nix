{ fetchFromGitHub, lib, stdenv, libX11, libXinerama, libXft, ... }:

stdenv.mkDerivation rec {
  pname = "dwm";
  version = "6.2";

  src = fetchFromGitHub {
    owner = "asdrubalini";
    repo = "dwm";
    rev = "9723664c2f827e0af7c762e75d480d09d0c80400";
    sha256 = "sha256-s3nN4OjtLvXujl5rvbQDuvAv1bhZ9O+ozGYUwIRuNOk=";
  };

  buildInputs = [ libX11 libXinerama libXft ];
  makeFlags = [ "PREFIX=$(out)" ];
  buildPhase = "make -j $(nproc)";
}
