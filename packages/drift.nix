{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "drift";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "phlx0";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-Gom5PQovsC9Q0jQN2kdJzo2D/uqKGA0i8wJ2Kc/XbfQ=";
  };

  vendorHash = "sha256-FsNa9qp2MnPk1onv/O13mFi+82yP7D4LdILZsNzHs+4=";

  ldflags = [
    "-s"
    "-w"
    "-X main.version=v${version}"
  ];

  meta = with lib; {
    description = "Terminal screensaver and ambient visualiser";
    homepage = "https://github.com/phlx0/drift";
    license = licenses.mit;
    mainProgram = "drift";
    platforms = platforms.unix;
  };
}
