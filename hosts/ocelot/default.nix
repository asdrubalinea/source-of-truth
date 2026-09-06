# ocelot — the per-project dev VM. One guest system, many individuals: nothing
# here varies per project, because the project path, the state disk, the ssh port
# and the guest's own name are all runtime parameters handed over by
# scripts/ocelot.sh. See docs/adr/0013-ocelot-per-project-dev-vm.md for the
# decisions and CONTEXT.md (*Isolation (tempest)*) for the vocabulary.
#
# Built and run by `ocelot`, never by nixos-rebuild:
#   nix build .#nixosConfigurations.ocelot.config.system.build.vm
#   ./result/bin/run-ocelot-vm          (needs the QEMU_OPTS the launcher sets)
#
# Three things cross the boundary, all over virtiofs (docs/adr/0013 explains why
# not 9p): the host /nix/store read-only under a scratch overlay, the project
# directory, and one staging directory the launcher assembles that carries the
# agent credentials plus this ocelot's identity. Everything else the guest has is
# either from the image or on its state disk.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/virtualisation/qemu-vm.nix")
    ../../modules/security.nix
    ./system/runtime.nix
    ./system/persistence.nix
    ./users/irene.nix
  ];

  virtualisation = {
    # Guest defaults from the ADR. memorySize is load-bearing twice: the
    # memory-backend-memfd below MUST be the same size or QEMU refuses to start
    # (same constraint hosts/tempest/vm.nix documents for virgl).
    memorySize = 8192;
    cores = 4;

    # No display: an ocelot is entered over ssh. This also puts the guest console
    # on stdio, which is what makes `journalctl --user -u ocelot-<name>` show the
    # boot.
    graphics = false;

    # tmpfs root. Ephemeral root is the update mechanism: the launcher rebuilds
    # from the current tree on every start, so a change to
    # desktop/cli-packages.nix reaches every ocelot at its next boot with no
    # per-guest rebuild to remember.
    diskImage = null;

    # The host store, read-only, with a writable overlay for the guest's own
    # builds so `nix develop` works inside. mountHostNixStore is deliberately
    # off: it shares the store over 9p, and the store is the guest's execution
    # path — every binary it runs is read across the share. So /nix/.ro-store is
    # declared by hand below as virtiofs instead, and the /nix/store overlay is
    # ours too, because qemu-vm only emits it for its own two store sources.
    #
    # writableStoreUseTmpfs is off because qemu-vm's /nix/.rw-store tmpfs is
    # sized at half of RAM — 3.9G of the guest's 8G — and a devshell does not fit
    # in it. A devenv `direnv allow` filled it and died with "write of 65536
    # bytes: No space left on device" while the 63G state disk sat at 0.6M used.
    # The overlay's upper is on that disk now (below), so the ceiling is the
    # disk, and half the guest's RAM stops being a store.
    writableStore = true;
    writableStoreUseTmpfs = false;
    mountHostNixStore = false;

    # qemu-vm's xchg/shared 9p mounts are test-driver scaffolding, and they are
    # neededForBoot, so they are two ways for a boot to fail for no benefit here.
    sharedDirectories = lib.mkForce {};

    # Networking is passt, started by the launcher, so the netdev is passed at
    # runtime through QEMU_OPTS along with the virtiofs chardevs and the state
    # disk. Nothing about it can be baked: the forwarded port differs per ocelot.
    #
    # mkForce, not a plain []: qemu-vm *defines* this option in its own config
    # (not merely as a default) and the type is a list, so a bare [] concatenates
    # with the SLiRP netdev instead of replacing it — the guest then comes up
    # with two network cards and passt is not one of them.
    qemu.networkingOptions = lib.mkForce [];

    qemu.options = [
      # Shared memory backend. vhost-user (which is what virtiofsd speaks) needs
      # the guest's RAM to be mappable by another process, and a plain -m
      # allocation is not. size MUST equal memorySize above.
      "-object"
      "memory-backend-memfd,id=mem0,size=8192M,share=on"
      "-machine"
      "memory-backend=mem0"
    ];

    fileSystems = {
      # The host store. `ro` is belt-and-braces — virtiofsd is started with
      # --readonly too, so neither side can write it.
      "/nix/.ro-store" = {
        device = "nix-store";
        fsType = "virtiofs";
        neededForBoot = true;
        options = ["ro"];
      };

      # Writable overlay over it, upper on the state disk.
      #
      # This was a tmpfs wiped every boot, on the argument that a persistent
      # overlay forgets its DB across reboots (microvm.nix documents this) and
      # drifts into orphans that neither nix nor GC can reason about. That
      # argument only holds while the DB is not persisted *with* it — so
      # /nix/var/nix is on the state disk too (./system/persistence.nix) and the
      # two move as one. What it buys is the point of a dev VM: a devshell is
      # downloaded once per ocelot, not once per boot.
      #
      # The host store is still only the lower, and the guest's Nix DB still
      # only knows the guest's own closure, so the first `direnv allow` in a
      # fresh ocelot re-fetches what tempest already has. Registering the host's
      # whole DB here (`nix-store --dump-db | nix-store --load-db`, ~80k paths,
      # 54M, 80s) is deliberately NOT done: it would make the guest depend on
      # host paths that nothing gcroots, so the weekly `nh clean all` would
      # quietly invalidate them.
      #
      # The overlayfs module mkdir -p's these and orders the mount after /state
      # on its own (its `depends`), so nothing else has to create them.
      "/nix/store".overlay = {
        lowerdir = ["/nix/.ro-store"];
        upperdir = "/state/nix-store/upper";
        workdir = "/state/nix-store/work";
      };

      # Everything that survives a `stop`. A raw ext4 image the launcher creates
      # and formats; see ./system/persistence.nix for what is bound out of it.
      "/state" = {
        device = "/dev/disk/by-label/ocelot-state";
        fsType = "ext4";
        neededForBoot = true;
      };

      # The launcher's staging directory: this ocelot's identity, its ssh host
      # key, the project, and the agent credential dirs. Read ./system/runtime.nix
      # for what is done with it. NOT neededForBoot — nothing in the boot path
      # reads it.
      "/host" = {
        device = "ocelot-host";
        fsType = "virtiofs";
      };
    };
  };

  # /nix/.ro-store is mounted in the initrd, so the driver has to be there.
  boot.initrd.availableKernelModules = ["virtiofs" "fuse"];

  # A blast-radius boundary, not a security one (CONTEXT.md): the agent
  # credentials are carried in on purpose, so anything running in here can
  # already read them. A sudo password would protect nothing and would block the
  # non-interactive use this exists for. modules/security.nix already makes both
  # doas and sudo-rs passwordless for wheel; this only restates that the choice
  # is deliberate here rather than inherited.

  networking = {
    # Overwritten at boot with ocelot-<name> (./system/runtime.nix): one image
    # serves every ocelot, so the individual's name cannot be baked in.
    hostName = "ocelot";

    # passt is the only route in or out, and it forwards exactly the ports it was
    # told to. A second filter inside the guest would only make port-forward lie.
    firewall.enable = false;

    # passt runs a DHCP server; the default scripted dhcpcd picks the address,
    # routes and resolvers up from it.
    useDHCP = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
    # One key, ed25519, generated on tempest at creation time and seeded into
    # this ocelot's known_hosts in the same moment — so there is never a TOFU
    # prompt or a changed-key warning. ./system/runtime.nix installs it from
    # /host and is ordered before sshd-keygen, which skips a key that already
    # exists; that is the whole handshake. (An empty list looks tidier and is
    # worse: NixOS then emits an sshd-keygen unit with no ExecStart, which fails
    # loudly on every boot.)
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  # An ocelot keeps no /var/log: the console is the launcher's journal on
  # tempest, which outlives the guest and is where a failed boot is actually
  # read. For that to be true rather than aspirational, anything at warning or
  # above has to reach the console — the default sends it only to the guest's
  # own journal, which is unreachable precisely when it matters (sshd down).
  services.journald.extraConfig = ''
    ForwardToConsole=yes
    MaxLevelConsole=warning
  '';

  # The reason an ocelot exists. Not rootless podman: rootless buys nothing
  # inside a guest that is itself the boundary, and the daemon's images are the
  # thing that has to survive a stop (see ./system/persistence.nix).
  virtualisation.docker.enable = true;

  # fish is irene's shell (./users/irene.nix); NixOS wants it enabled system-wide
  # so it lands in /etc/shells and gets its completions.
  programs.fish.enable = true;

  # A minimum viable Nix, rather than ../../modules/nix.nix: that module turns on
  # weekly `nix.gc` and `nix.optimise`, and both are actively wrong here. The
  # store is an overlay over a read-only lower, so a GC or a hardlink pass in the
  # guest works against paths it does not own: most of what its DB calls valid
  # lives in tempest's store and cannot be deleted or rewritten from in here.
  #
  # The writable upper does now accumulate — it is on the state disk (above), so
  # a devshell fetched in January is still there in June. That is the point, and
  # the eraser is `ocelot destroy`, which drops the whole state disk. An ocelot
  # that has collected more than it is worth is cheaper to rebuild than to prune.
  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" "irene"];
    };
    gc.automatic = false;
    optimise.automatic = false;
  };

  environment.systemPackages = [pkgs.git]; # for `nix develop` on a flake in a git checkout

  time.timeZone = "Atlantic/Canary";
  i18n.defaultLocale = "en_GB.UTF-8";

  # Nothing here holds state that a stateVersion bump would migrate: the root is
  # rebuilt every boot and the state disk holds only /home and the docker store.
  system.stateVersion = "25.11";
}
