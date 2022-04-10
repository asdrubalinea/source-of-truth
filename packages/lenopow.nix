{ lib, fetchFromGitHub, stdenv, ... }:

stdenv.mkDerivation rec {
  pname = "lenopow";
  version = "c2a29a38aee4014ef58fd4f20894c13768eeca61";

  src = fetchFromGitHub {
    owner = "asdrubalini";
    repo = "lenopow";
    rev = version;
    sha256 = "sha256-aOXk616dRDPfDD+ObJ0OUgCSJHXMv8sZvh7+C7CgP8E=";
  };

  nativeBuildInputs = [ ];

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
