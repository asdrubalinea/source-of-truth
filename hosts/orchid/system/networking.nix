{ ... }:
{
  networking = {
    hostName = "orchid";
    hostId = "f00dbabe";
    networkmanager.enable = false;
    useDHCP = true;
    enableIPv6 = true;
    defaultGateway = "10.0.0.1";

    # Upstream internet
    # interfaces.enp4s0f0.ipv4.addresses = [
    #   {
    #     address = "10.0.0.10";
    #     prefixLength = 20;
    #   }
    # ];

    extraHosts = ''
      127.0.0.1 dscovr.test
      127.0.0.1 tak.dscovr.test
      127.0.0.1 admin.dscovr.test
      127.0.0.1 app.dscovr.test
      127.0.0.1 experiment.dscovr.test
      127.0.0.1 teams.dscovr.test
      127.0.0.1 sole24ore.dscovr.test
      127.0.0.1 workspace2nrt.dscovr.test
      127.0.0.1 workspace5nrt.dscovr.test
      127.0.0.1 workspace6nrt.dscovr.test
      127.0.0.1 workspace1tcb.dscovr.test
      127.0.0.1 workspace1basenrt.dscovr.test
      127.0.0.1 workspace2tcb.dscovr.test
    '';
  };
}
