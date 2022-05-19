{ stdenv, lib, fetchFromGitHub, cmake, sdrplay }:

stdenv.mkDerivation rec {
  pname = "rsp_tcp";
  version = "f518a1c7899ae402b97fe0d9d19ae10bdfc3f8e5";

  src = fetchFromGitHub {
    owner = "SDRplay";
    repo = "RSPTCPServer";
    rev = version;
    sha256 = "sha256-EWN7IAUAckC3cthWhxj9pVihh3cYYbYvVcF14ln6Mw8=";
  };

  nativeBuildInputs = [ cmake ];

  buildInputs = [ sdrplay ];

  meta = with lib; {
    description = "RSP TCP Server";
    longDescription = ''
      TCP Server based on rsp_tcp for the SDRPlay SDRs series.
    '';
    homepage = "https://github.com/SDRplay/RSPTCPServer";
    license = licenses.unfree;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
