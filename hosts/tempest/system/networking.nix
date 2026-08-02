{lib, ...}: let
  # Local development stack: every name below is served by the reverse proxy
  # running on this machine, so the `*.dscovr.test` domain works offline.
  devDomain = "dscovr.test";

  # Product surfaces.
  devServices = [
    "admin"
    "api"
    "app"
    "experiment"
    "tak"
    "teams"
  ];

  # Per-tenant workspaces exercised against the local stack.
  devWorkspaces = [
    "acea"
    "alotofpeoplenrt"
    "alotofpeopletcb"
    "bofrost"
    "complexcasenrt"
    "sole24ore"
    "workspace-turco-meccanico-dominio"
    "workspace0tcb"
    "workspace1basenrt"
    "workspace1tcb"
    "workspace2nrt"
    "workspace2tcb"
    "workspace3tcb"
    "workspace4tcb"
    "workspace5nrt"
    "workspace5tcb"
    "workspace6nrt"
    "workspace7communicationnrt"
    "workspace8nrt"
    "workspace9nrt"
  ];

  devHosts =
    [devDomain]
    ++ map (sub: "${sub}.${devDomain}") (devServices ++ devWorkspaces);
in {
  # LocalSend — AirDrop-style LAN file sharing. openFirewall handles TCP+UDP 53317.
  programs.localsend = {
    enable = true;
    openFirewall = true;
  };

  networking = {
    hostName = "tempest";
    hostId = "856ff057";

    networkmanager.enable = true;

    firewall.allowedTCPPorts = [];
    firewall.allowedUDPPorts = [];

    extraHosts = lib.concatMapStringsSep "\n" (host: "127.0.0.1 ${host}") devHosts;
  };
}
