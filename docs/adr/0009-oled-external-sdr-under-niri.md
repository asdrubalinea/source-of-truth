# OLED external driven SDR under niri, direct USB-C, fractional scale via kanshi

Status: accepted

tempest's external display is now a 27" 4K QD-OLED (MSI MAG 272UP QD-OLED E16,
3840x2160@165). We drive it as the **solo clamshell** display (lid closed, eDP-1
disabled), connected **direct USB-C DP-alt to the laptop rather than through the
CalDigit Thunderbolt dock**, at **fractional scale 1.5** (logical 2560x1440)
configured through kanshi (the `oled-desk` profile in `homes/tempest/monitors.nix`).
It runs **SDR with VRR off**; burn-in is handled by auto-hiding the Noctalia bar,
grayscale font AA, `ddcutil` brightness, and the existing idle→DPMS chain.

## Why these deviations (a future reader will want to "fix" them)

- **Direct USB-C, not the dock.** Everything else on tempest rides the dock's DP
  tunnels, so putting the *primary* screen on a direct cable looks inconsistent.
  It's deliberate: 4K@165 wants the full DSC-backed pipe, and a direct link keeps
  the main display out of the ADR-0008 redock failure (black-after-resume until
  the Thunderbolt tunnels rebuild). The dock still carries power + peripherals.
- **SDR, not HDR.** The panel is DisplayHDR True Black 400, but niri has no
  color-management/HDR support, so HDR is *unavailable*, not declined. QD-OLED
  contrast, blacks, and color volume are panel properties and fully present in
  SDR. If one game ever needs HDR, gamescope does per-game HDR without leaving
  niri.
- **VRR off.** The panel is FreeSync Premium Pro capable, but QD-OLED +
  always-on VRR causes visible brightness flicker, and kanshi can only express
  always-on VRR — niri's safer `on-demand` mode is a niri-native output feature.
  Off is the right desktop default.
- **Scale via kanshi, with a niri-native fallback.** All monitor layout is kanshi
  "machine policy" (ADR-0004), so the OLED stays there for consistency. But
  fractional scale over kanshi's wlr-output-management path is unverified on niri;
  if `niri msg outputs` shows the OLED still at 3840x2160 after `scale = 1.5`,
  this one output moves to a niri-native `output` block (which also unlocks
  on-demand VRR and `max-bpc` later).
- **Grayscale font AA, globally.** `subpixel.rgba` changed from "rgb" to "none"
  because QD-OLED's triangular subpixels fringe text under RGB subpixel AA.
  fontconfig can't do this per-monitor, so it also slightly softens the low-DPI
  LCD externals — an accepted trade at their pixel densities.

## Consequences

- OLED brightness goes over DDC/CI (`ddcutil`, VCP `0x10`), enabled by
  `hardware.i2c.enable`; `brightnessctl` only drives the (disabled) laptop
  backlight when clamshell. The Mod brightness keys now branch on whether eDP-1
  is an active niri output.
- The `oled-desk` kanshi profile ships as a **scaffold**: its `criteria`
  (make/model/serial) and exact `mode` refresh must be captured from
  `niri msg outputs` on first connect. Until then the OLED falls through to the
  `external-only` profile at scale 1.0 (unusably tiny at 163 PPI).
