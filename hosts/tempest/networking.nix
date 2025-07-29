{ ... }:
{
  # Basic network configuration
  networking = {
    hostName = "tempest";
    hostId = "856ff057";
    networkmanager.enable = true;

    # Development environment hosts
    extraHosts = ''
      127.0.0.1 dscovr.test
      127.0.0.1 tak.dscovr.test
      127.0.0.1 admin.dscovr.test
      127.0.0.1 app.dscovr.test
      127.0.0.1 experiment.dscovr.test
      127.0.0.1 teams.dscovr.test
      127.0.0.1 acea.dscovr.test
      127.0.0.1 workspace5nrt.dscovr.test
      127.0.0.1 workspace0tcb.dscovr.test
      127.0.0.1 workspace2nrt.dscovr.test
      127.0.0.1 workspace6nrt.dscovr.test
    '';
  };

  # DNS configuration with NextDNS over TLS for privacy and security
  services.resolved = {
    enable = true;
    dnssec = "true";
    domains = [ "~." ];
    fallbackDns = [ "1.1.1.1" "1.0.0.1" ];
    extraConfig = ''
      DNS=45.90.28.0#3e5f5a.dns.nextdns.io
      DNS=2a07:a8c0::#3e5f5a.dns.nextdns.io
      DNS=45.90.30.0#3e5f5a.dns.nextdns.io
      DNS=2a07:a8c1::#3e5f5a.dns.nextdns.io
      DNSOverTLS=yes
    '';
  };
}
