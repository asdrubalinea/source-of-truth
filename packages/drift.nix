{
  lib,
  buildGoModule,
  src,
}:
buildGoModule {
  pname = "drift";
  version = src.shortRev or src.dirtyShortRev or "dev";

  inherit src;

  vendorHash = "sha256-xcSoDytK7cQrECa5PVoLunCG5im2YbOd8/0bclvTaq0=";

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
