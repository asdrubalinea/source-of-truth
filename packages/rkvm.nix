{ lib, fetchFromGitHub, rustPlatform, pkg-config, openssl, libevdev
, llvmPackages_latest, linuxHeaders }:

rustPlatform.buildRustPackage rec {
  pname = "rkvm";
  version = "bf133665eb446d9f128d02e4440cc67bce50f666";

  src = fetchFromGitHub {
    owner = "htrefil";
    repo = pname;
    rev = version;
    sha256 = "sha256-naWoLo3pPETkYuW4HATkrfjGcEHSGAAXixgp1HOlIcg=";
  };

  cargoSha256 = "sha256-RH9TKCY5G+xdj7TVEYkW9KrYItCbsfVa2cfP+OGfglk=";

  nativeBuildInputs = [ pkg-config openssl llvmPackages_latest.libclang ];
  LIBCLANG_PATH = "${llvmPackages_latest.libclang.lib}/lib";
  buildInputs = [ openssl libevdev linuxHeaders ];

  meta = with lib; {
    description = "Virtual KVM switch for Linux machines";
    homepage = "https://github.com/htrefil/rkvm";
    license = licenses.mit;
  };
}
