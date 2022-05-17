{ stdenv, lib, fetchFromGitHub, cmake, sdrplay, pkg-config, libconfig, lame, libshout, fftwFloat }:

stdenv.mkDerivation rec {
  pname = "rtl_airband";
  version = "7c80a9fd1e681f9f30e7532be275fca086443227";

  src = fetchFromGitHub {
    owner = "szpajder";
    repo = "RTLSDR-Airband";
    rev = version;
    sha256 = "sha256-WtUPk/KCr3nP41np6vT5TKfDFJamSaEtFWY/f1KYsIw=";
  };

  nativeBuildInputs = [ pkg-config libconfig lame cmake libshout fftwFloat ];

  buildInputs = [ sdrplay ];
}
