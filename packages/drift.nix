{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "drift";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "phlx0";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-jI6SFbOOp6iS0ERejcQE3YQNDTWTWpsMUCrJr/vKgRw=";
  };

  vendorHash = "sha256-0Rn42VLNV+4HFJomMfiCp8g4tdq+5yE/KMIUSpan8t8=";

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
