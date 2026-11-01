# Encrypted DNS through systemd-resolved: Quad9 over DNS-over-TLS, Cloudflare
# as the fallback. Before this, both hosts asked whatever resolver DHCP handed
# out, in plaintext. The firejail'd librewolf already pins Quad9
# (modules/firejail.nix), so this makes the rest of the system agree with it.
#
# Domains = "~." makes the global servers the route for every lookup, so the
# DHCP-pushed servers (NetworkManager on tempest, dhcpcd on orchid) only ever
# answer for their own search domains. The resolved module points
# NetworkManager at resolved itself.
#
# DNSOverTLS is strict: a network that blocks 853 gets no DNS rather than a
# silent plaintext downgrade. For a captive portal, hand the link its own DNS
# back until it's through, then revert:
#   resolvectl dnsovertls wlan0 no && resolvectl domain wlan0 '~.'
#   resolvectl revert wlan0
{
  networking.nameservers = [
    "9.9.9.9#dns.quad9.net"
    "149.112.112.112#dns.quad9.net"
    "2620:fe::fe#dns.quad9.net"
    "2620:fe::9#dns.quad9.net"
  ];

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSOverTLS = true;
      Domains = ["~."];
      FallbackDNS = [
        "1.1.1.1#cloudflare-dns.com"
        "1.0.0.1#cloudflare-dns.com"
        "2606:4700:4700::1111#cloudflare-dns.com"
        "2606:4700:4700::1001#cloudflare-dns.com"
      ];
      # Quad9 and Cloudflare validate upstream; resolved's own validator is
      # what breaks on odd networks, so it stays off.
      DNSSEC = false;
      # avahi owns mDNS (nssmdns4 in each host's networking.nix), and LLMNR
      # only announces the hostname to whoever shares the wifi.
      MulticastDNS = false;
      LLMNR = false;
    };
  };
}
