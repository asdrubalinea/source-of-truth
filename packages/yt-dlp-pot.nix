# yt-dlp that can still download from YouTube.
#
# Plain `pkgs.yt-dlp` currently gets HTTP 403 on nearly every video (5 of 6 in a
# spot check on 2026-08-19; only a 2005 upload survived). Nothing is wrong with
# the version — 2026.07.04 is what both nixpkgs-unstable and PyPI ship, and
# building git master changes nothing. Three separate gates have to be passed:
#
#   1. A JavaScript runtime, for YouTube's challenge. Without one yt-dlp silently
#      falls back to the `android_vr` client, whose stream URLs then 403. `deno`
#      is on the wrapper's PATH for this ("JS runtimes: deno" in `-v` output).
#   2. A Proof-of-Origin token. Stock yt-dlp reports "PO Token Providers: none";
#      the bgutil plugin in the python env below registers the `bgutil:http`
#      provider, which mints tokens against a small local server — run as a user
#      service, see ../desktop/yt-dlp.nix.
#   3. A client that is not SABR-only. Even holding a valid token, `web_safari`
#      and friends hand back formats "missing a URL. YouTube is forcing SABR
#      streaming for this client" (yt-dlp#12482), and yt-dlp falls back to the
#      403ing one. `tv_simply`, `web_embedded` and `mweb` still return real URLs;
#      no single one of them covers every video, but the three together did cover
#      all six tested, at 2160p AV1.
#
# The client list is baked in with --add-flags rather than left to a config file
# so that mpv's ytdl_hook gets it too — it invokes yt-dlp directly, and passing
# the value through mpv's --ytdl-raw-options is not possible anyway (mpv splits
# that option's value on commas, and the client list contains them). A caller
# that wants different clients can still pass its own --extractor-args, since
# wrapper flags come first and the later value wins.
#
# Expect the client list to rot: it describes which of YouTube's clients are
# unfenced this month, not anything durable. When 403s come back, re-run the
# matrix (`yt-dlp --extractor-args youtube:player_client=<one> -f ba -o - <url>`
# over each client) and update the list.
{ lib
, runCommand
, makeWrapper
, python3Packages
, deno
, ffmpeg
}:
let
  # The plugin has to share an interpreter with yt-dlp: discovery works by
  # importing the `yt_dlp_plugins` namespace package off sys.path, not by any
  # search of the filesystem.
  env = python3Packages.python.withPackages (ps: [
    ps.yt-dlp
    ps.bgutil-ytdlp-pot-provider
  ]);
in
runCommand "yt-dlp-pot"
{
  nativeBuildInputs = [ makeWrapper ];
  meta = {
    description = "yt-dlp with a PO-token provider, a JS runtime and non-SABR clients";
    mainProgram = "yt-dlp";
  };
} ''
  mkdir -p $out/bin
  # Only bin/yt-dlp is exposed: linking the whole python env into the profile
  # would drop a bin/python3 there too.
  makeWrapper ${env}/bin/yt-dlp $out/bin/yt-dlp \
    --prefix PATH : ${lib.makeBinPath [ deno ffmpeg ]} \
    --add-flags --extractor-args \
    --add-flags 'youtube:player_client=tv_simply,web_embedded,mweb'
''
