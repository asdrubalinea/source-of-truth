# Chrome video artifacts on tempest — blocky, moving regions

**Status: UNRESOLVED.** Root cause not established. Two confounds were found and
removed from consideration; the decisive test (Chrome at true 2160p with the
`enhanced-h264ify` extension disabled) has not been run yet. Nothing in this tree
has been changed.

## Symptom

Video in Chrome shows **hard-edged rectangular blocks** carrying a slight
brightness / haze offset. Picture content lines up *across* the boundaries — only
the tint differs — the blocks **move between frames**, and they are not on a fixed
grid. Both external displays (MSI MAG 272U on DP-2, BOE portable on DP-7), never
on the static desktop, windowed as well as fullscreen. Image quality also reads
as worse than the nominal 4K.

The artifact **is** present in `grim` screenshots, so it is in the frame, not on
the wire and not the panel.

Reported as a **regression** — 4K is believed to have worked correctly earlier.
Also reported absent under niri (untested).

## Confound 1: `enhanced-h264ify` (installed as an attempted fix)

`enhanced-h264ify` v2.2.1 is installed in the Chrome profile. It blocks VP9 and
AV1, so YouTube falls back to H.264 — and **YouTube's H.264 stops at 1080p**, so
1440p/2160p never appear in the quality menu. Chrome then upscales a low-bitrate
1080p H.264 stream 2–3× onto a 1440p/4K panel, which magnifies its macroblocks
into something closely resembling the reported symptom.

**This is not the root cause** — the artifact predates the extension's
installation. But while it is enabled, any observation of Chrome video is
measuring the extension, not the original bug. **Disable it before testing.**

It also explains the "Chrome caps at 1080p while Zen offers the 4K selector"
observation completely, and is worth removing regardless: it was installed on the
theory that only H.264 decoded in hardware, and that is false here — `vainfo`
reports VP9 Profile 0/2 and AV1 Profile 0 under `VAEntrypointVLD`.

Chrome's own capability report (probed in the real browser via
`navigator.mediaCapabilities.decodingInfo`) says every format is fine —
vp9 2160p and av1 2160p all `supported / smooth / powerEfficient = true`. So
Chrome's media stack is not refusing 4K; the extension is withholding it.

The same probe incidentally revealed the **User-Agent is spoofed** to
`Windows NT 10.0 ... Chrome/136.0.7103.48` while the binary is 151.0.7922.137 —
some other extension is rewriting it. Unrelated to this bug, but worth knowing.

## Confound 2: the AV1 decoder comparison (probably a harness artifact)

An earlier round measured VAAPI/VCN AV1 hardware decode against `dav1d` software
decode and found: luma mean abs diff 3.18, max 95, **0 of 382 frames matching**
by `framemd5` at any alignment offset, with the error spatially clustered (32px
block-mean median 2.19, p99 25.82, max 68.05; worst 0.5% of blocks inside one
rectangle at x 1632–1792, y 512–800).

**Treat this as unproven.** Two serious problems with it:

1. It was measured on the **AV1 stream that `yt-dlp` fetches**, which is *not*
   what Chrome was playing — with `enhanced-h264ify` active Chrome was receiving
   H.264 1080p. The measurement therefore describes mpv's path, not Chrome's, and
   cannot have caused the reported symptom.
2. The `hwdownload` path in the comparison is a plausible source of a systematic
   difference on its own, so the uniform component (signed mean −1.15) is likely
   the harness. The *clustered* tail is harder to explain that way, but was never
   independently confirmed.

One piece of independent support survives: `mpv --hwdec=vaapi` on a 1440p60 AV1
stream produced **steadily climbing dropped frames** (1→8 while stalled at one
timestamp) with the cache healthy at 1.5–2.0 s, so it was not data-starved. The
VCN AV1 path may genuinely struggle. Re-test properly if step 1 below implicates
hardware decode.

## Test plan (not yet executed)

1. Disable `enhanced-h264ify`, hard-reload YouTube, select 2160p. Confirm what is
   actually being decoded via **Stats for nerds** (`Codecs`, `Viewport`,
   `Frames`) or `chrome://media-internals` — do not infer Chrome's stream from
   `yt-dlp`.
   - Artifacts gone ⇒ the extension accounted for the current symptom; whatever
     was seen earlier is a separate, milder question.
   - Artifacts persist at true 2160p AV1 ⇒ continue to 2.
2. Isolate hardware decode in a throwaway profile (avoids disturbing the real
   profile, and stays windowed — see the kanshi hazard below):

   ```sh
   google-chrome-stable --user-data-dir=/tmp/chrome-swtest \
     --disable-accelerated-video-decode "$URL"
   ```

   Clean there but broken normally ⇒ hardware video decode is implicated.
3. If it is a regression, bisect what changed: Chrome 151, Mesa 26.2.0, the
   kernel, or the niri→mango switch. The decode hypothesis fits a Mesa or Chrome
   bump; it does **not** fit a compositor switch.

## Ruled out, by measurement

- **DSC on the display link.** 4K@165 does mathematically require DSC
  (32.85 Gbps vs the 25.92 Gbps HBR3 ceiling), but dropping DP-2 to 120 Hz
  changed nothing.
- **Gamma LUT / wlsunset.** Read the `GAMMA_LUT` blobs off `/dev/dri/card1` via
  `DRM_IOCTL_MODE_GETPROPBLOB`: both are **exact identity** (256 in → 256
  distinct out, max step 1).
- **8-bit banding / output bit depth.** Real but a *different* artifact from the
  one reported. `max bpc = 8` on both DP connectors, framebuffer `XRGB8888`, and
  88–95% of banding edges are exactly 1 LSB with no histogram gaps — textbook
  8-bit quantisation. 10-bit is unreachable anyway (mango composites
  `XRGB8888`, exposes no bit-depth option) and would not help an 8-bit source.
- **AV1 film grain synthesis.** `-filmgrain 0` vs `1` is **bit-exact**, so this
  stream carries no grain metadata at all.

## Instrument traps

Every one of these produced a confident wrong answer during this investigation:

- **Check what the application is actually being served before analysing how it
  processes it.** The single biggest time sink here: `yt-dlp` was handing over
  AV1 1440p while Chrome was being fed H.264 1080p by an extension. Two rounds of
  decoder analysis described the wrong pipeline.
- **`-ss` fast-seek lands the two decoders on different frames**, yielding a
  bogus "99.66% of pixels differ". Capture a segment with `-c copy` first, then
  index frames inside the local file.
- **`hwdownload` drops colour metadata**, so comparing after `-pix_fmt rgb24`
  measures your own bt709/range mismatch (a convincing uniform mean of 6.44),
  not the decoder. Compare raw YUV planes.
- **`-vsync` is gone** from current ffmpeg; use `-fps_mode passthrough`.
- **Match the detector to the artifact's geometry.** A median step down a full
  image column finds straight full-height seams (DSC slices, pipe splits) but is
  blind to banding, whose contours follow curved iso-luminance lines and dilute
  to ~0.3/255 — reading as "the framebuffer is clean". That false negative
  generated the DSC and gamma-LUT theories. A banding detector is in turn blind
  to blocks.
- **A hand-made gradient test image quantises itself.** A 0→45 ramp across
  3840 px has only 46 levels, so it shows 83.5 px strips *by construction* and
  "reproduces" a bug that exists entirely in the PNG. Dither test patterns.

## Operational hazard while testing this

**Launching a fullscreen video player forces a modeset, and kanshi does not
re-assert its profile when output state changes underneath it** — it half-applies
and leaves `eDP-1` enabled with wrong positions. Same after `wlr-randr --mode`.
Keep test playback **windowed**.

Recovery is a full restart, not an IPC switch (`kanshictl switch` fixed modes but
neither positions nor the disable):

```sh
systemctl --user restart kanshi
```
