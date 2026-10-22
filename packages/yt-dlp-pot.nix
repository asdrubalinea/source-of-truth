# yt-dlp that can still download from YouTube.
#
# Plain `pkgs.yt-dlp` 403s on nearly every video, and not because of its version
# (git master changes nothing). Three gates have to be passed:
#
#   1. A JS runtime for YouTube's challenge. Without one yt-dlp silently falls
#      back to `android_vr`, whose stream URLs 403. `deno` is on the wrapper's
#      PATH for this — confirm with "JS runtimes: deno" in `-v` output.
#   2. A Proof-of-Origin token. Stock yt-dlp reports "PO Token Providers: none";
#      the bgutil plugin below registers `bgutil:http`, which mints tokens
#      against a small local server (a user service, ../desktop/yt-dlp.nix).
#   3. A client that is not SABR-only. Even with a valid token, `web_safari` and
#      friends return formats "missing a URL" (yt-dlp#12482) and yt-dlp falls
#      back to the 403ing one. No single unfenced client covers every video, so
#      three are listed.
#
# The list is baked in with --add-flags rather than a config file so mpv's
# ytdl_hook gets it too — it invokes yt-dlp directly, and mpv's
# --ytdl-raw-options can't carry it anyway (mpv splits that value on commas). A
# caller can still override with its own --extractor-args, since wrapper flags
# come first and the later value wins.
#
# EXPECT THE CLIENT LIST TO ROT — it describes which of YouTube's clients are
# unfenced this month. When 403s return, re-run the matrix
# (`yt-dlp --extractor-args youtube:player_client=<one> -f ba -o - <url>` per
# client) and update it.
{
  lib,
  runCommand,
  makeWrapper,
  python3Packages,
  deno,
  ffmpeg,
}: let
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
    nativeBuildInputs = [makeWrapper];
    meta = {
      description = "yt-dlp with a PO-token provider, a JS runtime and non-SABR clients";
      mainProgram = "yt-dlp";
    };
  } ''
    mkdir -p $out/bin
    # Only bin/yt-dlp is exposed: linking the whole python env into the profile
    # would drop a bin/python3 there too.
    makeWrapper ${env}/bin/yt-dlp $out/bin/yt-dlp \
      --prefix PATH : ${lib.makeBinPath [deno ffmpeg]} \
      --add-flags --extractor-args \
      --add-flags 'youtube:player_client=tv_simply,web_embedded,mweb'
  ''
