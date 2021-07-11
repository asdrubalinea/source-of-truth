with import <nixpkgs> { };

stdenv.mkDerivation rec {
  pname = "dwmblocks";
  version = "latest";
  src = fetchFromGitHub {
    owner = "asdrubalini";
    repo = "dwmblocks";
    rev = "8e3b561555c631a409bd6e7291ed461459d652e9";
    sha256 = "10kmckdwr4si9a029s3z0y90diyvxr176iis68bxqfd08qg6yv77";
  };
  buildInputs = [ xorg.libX11 ];
  makeFlags = [ "PREFIX=$(out)" ];
  buildPhase = "make -j $(nproc)";
}
