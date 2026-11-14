{
  stdenvNoCC,
  fetchFromGitHub,
  gleam,
  erlang,
  esbuild,
  cacert,
}:
# The GTA VI countdown (Gleam + Lustre) built to a static page loadable over
# file://. Upstream's `lustre/dev build` pulls bun/esbuild binaries at run time,
# so this compiles with plain `gleam build` and bundles with nixpkgs' esbuild.
let
  src = fetchFromGitHub {
    owner = "asdrubalinea";
    repo = "vice_countdown";
    rev = "b92e758c27fe801a9d330bb104030cf378069360";
    hash = "sha256-7E7Zdx2WsdW1j0vhgZWOsC3T8Jy84CgQYYVGCoFX2tU=";
  };

  # Hex packages from manifest.toml, fetched once as a fixed-output derivation.
  deps = stdenvNoCC.mkDerivation {
    name = "vice-countdown-deps";
    inherit src;
    nativeBuildInputs = [gleam erlang];
    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    buildPhase = "HOME=$TMPDIR gleam deps download";
    # gleam writes packages.toml in hash-map order; sort it or the hash drifts per run.
    installPhase = ''
      cp -r build/packages $out
      f=$out/packages.toml
      { sed -n 1p $f; sed '1d;/^$/,$d' $f | sort; sed -n '/^$/,$p' $f; } > sorted
      mv sorted $out/packages.toml
    '';
    outputHashMode = "recursive";
    outputHash = "sha256-TOtZ24w5AijYFzaIuKTbz3/W9rB9xJUEaGJPoI1Mo2I=";
  };
in
  stdenvNoCC.mkDerivation {
    pname = "vice-countdown";
    version = "0-unstable-2026-11-13";
    inherit src;
    nativeBuildInputs = [gleam erlang esbuild];

    # Root-absolute asset paths resolve to / under file://.
    postPatch = ''
      substituteInPlace src/countdown.gleam --replace-fail '"/gtavi.svg"' '"gtavi.svg"'
    '';

    buildPhase = ''
      mkdir -p build && cp -r ${deps} build/packages && chmod -R u+w build
      HOME=$TMPDIR gleam build --target javascript
      echo 'import { main } from "./build/dev/javascript/countdown/countdown.mjs"; main();' > entry.mjs
      # iife, not an ES module: WebKit refuses module scripts from file:// origins.
      esbuild entry.mjs --bundle --minify --format=iife --outfile=app.js
    '';

    installPhase = ''
      mkdir -p $out
      cp app.js assets/style.css assets/gtavi.svg $out/
      cat > $out/index.html <<'EOF'
      <!doctype html>
      <html><head><meta charset="utf-8"><title>GTA VI Countdown</title>
      <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Unbounded:wght@300;400;800&display=swap">
      <link rel="stylesheet" href="style.css"></head>
      <body><div id="app"></div><script src="app.js"></script></body></html>
      EOF
    '';
  }
