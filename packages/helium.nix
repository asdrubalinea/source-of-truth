# Helium, set up for a profile that roams between tempest and orchid over
# syncthing (services/syncthing.nix, docs/helium-sync.md):
#
# - `--password-store=basic`: cookies (and any saved passwords) are encrypted
#   with a key from the login keyring, which is random per machine, so a synced
#   profile would arrive with every site logged out. The basic store derives a
#   fixed key instead; on a LUKS disk, obfuscation at rest is all that's lost.
# - bin/helium is a guard script: it waits for the syncthing folder to settle
#   before starting the browser, and after the browser quits it reports when the
#   other host has received everything. The .desktop entry goes through it too.
{
  lib,
  symlinkJoin,
  writeShellApplication,
  curl,
  jq,
  libnotify,
  procps,
  gnugrep,
  coreutils,
  helium-unwrapped,
}: let
  helium = helium-unwrapped.override {
    flags = ["--password-store=basic"];
  };

  guard = writeShellApplication {
    name = "helium";
    runtimeInputs = [curl jq libnotify procps gnugrep coreutils];
    text =
      ''
        HELIUM=${helium}/bin/helium
        SYNCTHING_CONFIG=/persist/syncthing-config/config.xml
        FOLDER=helium
      ''
      + builtins.readFile ./helium-guard.sh;
  };
in
  symlinkJoin {
    name = "helium-roaming-${helium.version}";
    paths = [helium];
    postBuild = ''
      rm $out/bin/helium
      ln -s ${guard}/bin/helium $out/bin/helium
      rm $out/share/applications/helium.desktop
      sed 's|${helium}/bin/helium|'"$out"'/bin/helium|g' \
        ${helium}/share/applications/helium.desktop \
        > $out/share/applications/helium.desktop
    '';
    passthru = {
      inherit (helium) version;
      unwrapped = helium;
    };
    meta = helium.meta // {mainProgram = "helium";};
  }
