{
  lib,
  buildGoModule,
  src,
}:
buildGoModule {
  pname = "drift";
  version = src.shortRev or src.dirtyShortRev or "dev";

  inherit src;

  vendorHash = "sha256-FsNa9qp2MnPk1onv/O13mFi+82yP7D4LdILZsNzHs+4=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Terminal screensaver and ambient visualiser";
    homepage = "https://github.com/phlx0/drift";
    license = licenses.mit;
    mainProgram = "drift";
    platforms = platforms.unix;
  };
}
