{ ... }:
{
  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        KbdInteractiveAuthentication = false;
      };
    };

    # Headless discovery on a DHCP LAN: publishes zephyr.local over mDNS so the
    # first contact is `ssh irene@zephyr.local` with no known IP.
    avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };

    # Joined once interactively after first boot: ssh in over the LAN and run
    # `sudo tailscale up`. No authkey is baked in, so no sops bootstrap needed.
    tailscale = {
      enable = true;
      openFirewall = true;
    };

    # Keep the journal in RAM. An always-on box logging to the SD card 24/7 is
    # the #1 way to wear the card out; cap it so it can't eat the 1 GB.
    journald.extraConfig = ''
      Storage=volatile
      RuntimeMaxUse=64M
    '';
  };

  # Compressed RAM swap (zero SD writes) for headroom on a 1 GB board. The Pi
  # never compiles (tempest builds and pushes), so this is for runtime pressure,
  # not build OOM.
  zramSwap.enable = true;
}
