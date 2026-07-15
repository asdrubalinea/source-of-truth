{ stdenv, lib, fetchFromGitHub, cmake, pkg-config, soapysdr }:

stdenv.mkDerivation rec {
  pname = "rx_tools";
  version = "811b21c4c8a592515279bd19f7460c6e4ff0551c";

  src = fetchFromGitHub {
    owner = "rxseger";
    repo = "rx_tools";
    rev = version;
    hash = "sha256-WacMVC0rohyHnZexGj2Zby9aD4AYwJvljACbzQDAKGM=";
  };

  nativeBuildInputs = [ cmake pkg-config ];

  # rx_tools' CMakeLists declares cmake_minimum_required(VERSION 2.6), and CMake
  # >= 4 dropped compatibility with < 3.5. Opt back in rather than patch upstream.
  cmakeFlags = [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];

  # SoapySDR-based clones of the rtl-sdr CLI tools (rx_sdr, rx_fm, rx_power).
  # rx_sdr streams I/Q to stdout with the same byte layout as
  # rtl_sdr — the plugin (rtlsdr / sdrplay / ...) is resolved at runtime via
  # SOAPY_SDR_PLUGIN_PATH, so linking the plain lib here is enough.
  buildInputs = [ soapysdr ];

  meta = with lib; {
    description = "SoapySDR command-line tools (rx_sdr/rx_fm/rx_power) modelled on rtl-sdr";
    homepage = "https://github.com/rxseger/rx_tools";
    license = licenses.gpl3Only;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
