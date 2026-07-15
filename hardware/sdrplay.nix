{ pkgs, ... }:
let
  # SoapySDR built with plugins for the radios irene actually has: the RTL-SDR
  # Blog V4 (soapyrtlsdr) and the SDRplay RSP1A (soapysdrplay). nixpkgs'
  # `soapysdr-with-plugins` bundles soapyrtlsdr and the rest but deliberately
  # OMITS soapysdrplay, because that plugin links the proprietary SDRplay API
  # (pkgs.sdrplay) — so we add it back explicitly here.
  soapysdr = pkgs.soapysdr.override {
    extraPackages = [ pkgs.soapyrtlsdr pkgs.soapysdrplay ];
  };

  # SoapySDR clones of the rtl-sdr CLI (rx_sdr/rx_fm/rx_power) — not in nixpkgs.
  # rx_sdr streams I/Q to stdout in the same byte layout as rtl_sdr, so it drops
  # straight into an existing `rtl_sdr ... | process` pipeline against the RSP1A.
  rx_tools = pkgs.callPackage ../packages/sdrplay/rx_tools.nix { inherit soapysdr; };
in
{
  # SDRplay RSP1A. `services.sdrplayApi` runs the proprietary sdrplay_apiService
  # daemon (SoapySDRPlay3 talks to it over a local socket — nothing works
  # without it) and installs the udev rules that let a non-root user open the
  # device. The daemon runs under a DynamicUser, so it needs no persisted state.
  services.sdrplayApi.enable = true;

  # SoapySDRUtil (probe / stream / rate list) plus the combined plugin set, so a
  # single `SoapySDRUtil --find` sees both radios and CLI streaming to a pipe
  # works out of the box: `SoapySDRUtil --probe="driver=sdrplay"`.
  environment.systemPackages = [ soapysdr rx_tools ];

  # Point every SoapySDR client at this package's module dir, so apps linked
  # against a plain `pkgs.soapysdr` (not this override) still load the rtlsdr +
  # sdrplay plugins. This is the usual NixOS gotcha — the plugins live in a
  # separate store path from the base lib unless SOAPY_SDR_PLUGIN_PATH says so.
  environment.variables.SOAPY_SDR_PLUGIN_PATH = "${soapysdr}/${soapysdr.passthru.searchPath}";
}
