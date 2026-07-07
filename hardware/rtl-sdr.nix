{ config, ... }:
{
  # RTL-SDR Blog V4 USB dongle (RTL2832U + R828D tuner).
  #
  # `hardware.rtl-sdr.enable` installs the udev rules (so the device is owned by
  # the `plugdev` group instead of root), ensures `plugdev` exists, and
  # blacklists the DVB-T kernel modules (dvb_usb_rtl28xxu et al.) that would
  # otherwise claim the dongle. irene is added to `plugdev` in users/irene.nix.
  #
  # No package override needed: nixpkgs' `rtl-sdr` is already the RTL-SDR Blog
  # fork (rtlsdrblog, 1.3.5), which carries the R828D / upconverter handling the
  # V4 needs — the stock osmocom driver doesn't drive it correctly. SDRangel
  # links this same `rtl-sdr`, so it talks to the V4 out of the box.
  hardware.rtl-sdr.enable = true;

  # CLI tools (rtl_test, rtl_fm, rtl_power, rtl_eeprom, rtl_sdr) from the exact
  # package the udev rules use — handy for verifying the dongle (`rtl_test -t`).
  environment.systemPackages = [ config.hardware.rtl-sdr.package ];
}
