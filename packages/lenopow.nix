{ lib, fetchFromGitHub, stdenv, ... }:

stdenv.mkDerivation rec {
  pname = "lenopow";
  version = "c2a29a38aee4014ef58fd4f20894c13768eeca61";

  src = fetchFromGitHub {
    owner = "asdrubalini";
    repo = "lenopow";
    rev = version;
    # sha256 = "sha256-7zaXazGzb36Nwk/meJ3lGD+l+fylWZYnhttDL1CXN9s=";
  };

  nativeBuildInputs = [ ];

  installPhase = ''
    runHook preInstall
    install -Dm755 -t "$out/bin" lenopow
    runHook postInstall
  '';

  meta = with lib; {
    description = "Toggle battery conservation mode on Lenovo laptops";
    homepage = "https://github.com/asdrubalini/lenopow";
    license = licenses.gplv3;
    maintainers = with maintainers; [ ];
  };
}
