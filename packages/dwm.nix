with import <nixpkgs> { };

stdenv.mkDerivation rec {
  pname = "dwm";
  version = "6.2";
  src = fetchFromGitHub {
    owner = "asdrubalini";
    repo = "dwm";
    rev = "d97fc8fdb6455a33678dcf7cf99514810c26ea96";
    sha256 = "0g5n020qybi9a27axqbw0a0cx3a44mlcc3m5p8n2bav7kahkwmma";
  };
  buildInputs = [ xorg.libX11 xorg.libXinerama xorg.libXft fira-code ];
  makeFlags = [ "PREFIX=$(out)" ];
  buildPhase = "make -j $(nproc)";
}
