{pkgs, ...}: let
  ocelot = pkgs.writeShellApplication {
    name = "ocelot";
    # bubblewrap is not a boundary here, only a way to compose mounts so one
    # virtiofsd can serve the project and the scattered credential dirs
    # together; passt gives the guest its one forwarded port; e2fsprogs formats
    # the state disk; socat drives the qemu monitor so `stop` is a clean
    # power-down; iproute2's ss finds a free port. qemu itself is not here — it
    # comes from the built VM runner, pinned to the guest it boots.
    runtimeInputs = with pkgs; [
      bubblewrap
      virtiofsd
      passt
      e2fsprogs
      coreutils
      gawk
      openssh
      socat
      iproute2
      systemd
    ];
    text = builtins.readFile ./ocelot.sh;
  };
in {
  home.packages = [ocelot];
}
