{ ... }:
{
  # Basic network configuration
  networking = {
    hostName = "tempest";
    hostId = "856ff057";
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 8000 ];

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
      127.0.0.1 alotofpeoplenrt.dscovr.test
      127.0.0.1 workspace4tcb.dscovr.test
      127.0.0.1 workspace2tcb.dscovr.test
      127.0.0.1 workspace1basenrt.dscovr.test
      127.0.0.1 workspace1tcb.dscovr.test
      127.0.0.1 alotofpeopletcb.dscovr.test
      127.0.0.1 workspace5tcb.dscovr.test
    '';
  };
}
