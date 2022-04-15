{ lib, fetchFromGitHub, stdenv, ... }:

stdenv.mkDerivation rec {
  pname = "lenopow";
  version = "607d46a2f4d0c12762d8f2e078938d93b79e8122";

  src = fetchFromGitHub {
    owner = "asdrubalini";
    repo = "lenopow";
    rev = version;
    sha256 = "sha256-hO5e8UQosQXFpHfYg3DWPp472VMndIVCfXU1ZovcQu8=";
  };

  installPhase = ''
    install -Dm755 -t "$out/bin" lenopow
  '';

  meta = with lib; {
    description = "Toggle battery conservation mode on Lenovo laptops";
    homepage = "https://github.com/asdrubalini/lenopow";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ ];
  };
}
