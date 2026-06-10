{ lib, ... }:
{
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  # Onboard Ethernet works with in-kernel drivers; redistributable firmware is
  # cheap insurance and keeps the door open for the onboard WiFi later
  # (brcmfmac needs it). First boot is wired Ethernet + DHCP regardless.
  hardware.enableRedistributableFirmware = true;
}
