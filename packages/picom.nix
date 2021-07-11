with import <nixpkgs> { };

stdenv.mkDerivation rec {
  pname = "picom";
  version = "latest";

  src = fetchFromGitHub {
    owner = "ibhagwan";
    repo = "picom";
    rev = "60eb00ce1b52aee46d343481d0530d5013ab850b";
    sha256 = "1m17znhl42sa6ry31yiy05j5ql6razajzd6s3k2wz4c63rc2fd1w";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    asciidoc
    docbook_xml_dtd_45
    docbook_xsl
    makeWrapper
    meson
    ninja
    pkg-config
    uthash
  ];

  buildInputs = [
    dbus
    libconfig
    libdrm
    libev
    libGL
    xorg.libX11
    xorg.libxcb
    xorg.libXext
    xorg.libXinerama
    libxml2
    libxslt
    pcre
    pixman
    xorg.xcbutilimage
    xorg.xcbutilrenderutil
    xorg.xorgproto
  ];

  mesonBuildType = "release";
  mesonFlags = [ "-Dwith_docs=true" ];
  installFlags = [ "PREFIX=$(out)" ];
  dontStrip = false;

  postInstall = ''
    wrapProgram $out/bin/picom-trans \
      --prefix PATH : ${lib.makeBinPath [ xorg.xwininfo ]}
  '';
}
