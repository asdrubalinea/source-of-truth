{lib, ...}: let
  # Local development stack: every name below is served by the reverse proxy
  # running on this machine, so the `*.dscovr.test` domain works offline.
  devDomain = "dscovr.test";

  devServices = [
    "admin"
    "app"
    "experiment"
    "sole24ore"
    "tak"
    "teams"
  ];

  devWorkspaces = [
    "complexcasenrt"
    "workspace1basenrt"
    "workspace1tcb"
    "workspace2nrt"
    "workspace2tcb"
    "workspace5nrt"
    "workspace6nrt"
  ];

  devHosts =
    [devDomain]
    ++ map (sub: "${sub}.${devDomain}") (devServices ++ devWorkspaces);
in {
  networking = {
    hostName = "orchid";
    # Required by ZFS, and stamped into the pool labels on import — do not change
    # it after the pool exists without also updating /etc/hostid.
    hostId = "f00dbabe";

    # No NetworkManager and no static addressing: there is no dedicated NIC in
    # this box yet, so leave `networking.useDHCP` at its default (true for every
    # interface) and let whatever appears — onboard ethernet, a card added later
    # — come up on DHCP with no config change. Add a static address here if this
    # host ever needs a fixed one again; the old defaultGateway = 10.0.0.1 and
    # commented enp4s0f0 block were both stale.

    extraHosts = lib.concatMapStringsSep "\n" (host: "127.0.0.1 ${host}") devHosts;
  };
}
