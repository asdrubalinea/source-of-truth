# ocelot — the per-project dev VM. One guest system, many individuals: nothing
# here varies per project, because the project path, the state disk, the ssh port
# and the guest's own name are runtime parameters handed over by
# scripts/ocelot.sh. See ADR 0013 for the decisions, CONTEXT.md
# (*Isolation (tempest)*) for the vocabulary.
#
# Built and run by `ocelot`, never by nixos-rebuild. Three things cross the
# boundary, all over virtiofs: the host /nix/store read-only under a scratch
# overlay, the project directory, and one staging directory carrying the agent
# credentials plus this ocelot's identity.
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
    # memorySize is load-bearing twice: the memory-backend-memfd below MUST be
    # the same size or QEMU refuses to start.
    memorySize = 8192;
    cores = 4;

    # An ocelot is entered over ssh. This also puts the guest console on stdio,
    # which is what makes `journalctl --user -u ocelot-<name>` show the boot.
    graphics = false;

    # Ephemeral root IS the update mechanism: the launcher rebuilds from the
    # current tree on every start, so a change to desktop/cli-packages.nix
    # reaches every ocelot at its next boot with no per-guest rebuild.
    diskImage = null;

    # mountHostNixStore is deliberately off — it shares the store over 9p, and
    # the store is the guest's execution path, so every binary it runs would be
    # read across that share. /nix/.ro-store is declared by hand as virtiofs
    # below instead, and the overlay with it, because qemu-vm only emits one for
    # its own two store sources.
    #
    # writableStoreUseTmpfs is off because that tmpfs is sized at half of RAM —
    # 3.9G of 8G — and a devshell does not fit: a devenv `direnv allow` died
    # with ENOSPC while the 63G state disk sat at 0.6M used. The overlay's upper
    # is on that disk now, so the ceiling is the disk.
    writableStore = true;
    writableStoreUseTmpfs = false;
    mountHostNixStore = false;

    # qemu-vm's xchg/shared 9p mounts are test-driver scaffolding and they are
    # neededForBoot — two ways for a boot to fail for no benefit here.
    sharedDirectories = lib.mkForce {};

    # Networking is passt, started by the launcher, so the netdev arrives at
    # runtime via QEMU_OPTS with the virtiofs chardevs and the state disk.
    # Nothing about it can be baked: the forwarded port differs per ocelot.
    #
    # mkForce, not a plain []: qemu-vm *defines* this option rather than
    # defaulting it, and the type is a list, so [] would concatenate with the
    # SLiRP netdev — the guest comes up with two cards and passt is not one.
    qemu.networkingOptions = lib.mkForce [];

    qemu.options = [
      # vhost-user (what virtiofsd speaks) needs the guest's RAM mappable by
      # another process, which a plain -m allocation is not. size MUST equal
      # memorySize above.
      "-object"
      "memory-backend-memfd,id=mem0,size=8192M,share=on"
      "-machine"
      "memory-backend=mem0"
    ];

    fileSystems = {
      # `ro` is belt-and-braces — virtiofsd is started with --readonly too.
      "/nix/.ro-store" = {
        device = "nix-store";
        fsType = "virtiofs";
        neededForBoot = true;
        options = ["ro"];
      };

      # Writable overlay, upper on the state disk. This was a tmpfs wiped every
      # boot, on the argument that a persistent overlay forgets its DB across
      # reboots and drifts into orphans — which only holds while the DB isn't
      # persisted *with* it, so /nix/var/nix is on the state disk too
      # (./system/persistence.nix) and the two move as one. What it buys is the
      # point of a dev VM: a devshell downloaded once per ocelot, not per boot.
      #
      # The guest's DB still only knows its own closure, so a fresh ocelot
      # re-fetches what tempest already has. Registering the host's whole DB
      # here is deliberately NOT done: it would make the guest depend on host
      # paths nothing gcroots, which the weekly `nh clean all` would invalidate.
      #
      # The overlayfs module mkdir -p's these and orders the mount after /state
      # itself, so nothing else has to.
      "/nix/store".overlay = {
        lowerdir = ["/nix/.ro-store"];
        upperdir = "/state/nix-store/upper";
        workdir = "/state/nix-store/work";
      };

      # Everything that survives a `stop`. A raw ext4 image the launcher creates
      # and formats; ./system/persistence.nix says what is bound out of it.
      "/state" = {
        device = "/dev/disk/by-label/ocelot-state";
        fsType = "ext4";
        neededForBoot = true;
      };

      # The launcher's staging directory: identity, ssh host key, the project,
      # and the agent credential dirs. See ./system/runtime.nix. NOT
      # neededForBoot — nothing in the boot path reads it.
      "/host" = {
        device = "ocelot-host";
        fsType = "virtiofs";
      };
    };
  };

  # /nix/.ro-store is mounted in the initrd, so the driver has to be there.
  boot.initrd.availableKernelModules = ["virtiofs" "fuse"];

  # A blast-radius boundary, not a security one (CONTEXT.md): the agent
  # credentials are carried in on purpose, so anything in here can already read
  # them. A sudo password would protect nothing and would block the
  # non-interactive use this exists for — modules/security.nix already makes
  # doas and sudo-rs passwordless for wheel, and that is deliberate here.

  networking = {
    # Overwritten at boot with ocelot-<name> (./system/runtime.nix): one image
    # serves every ocelot, so the name cannot be baked in.
    hostName = "ocelot";

    # passt is the only route in or out and forwards exactly the ports it was
    # told to. A second filter inside would only make port-forward lie.
    firewall.enable = false;

    # passt runs a DHCP server; scripted dhcpcd picks address/routes/resolvers
    # up from it.
    useDHCP = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
    # One ed25519 key, generated on tempest at creation time and seeded into
    # this ocelot's known_hosts in the same moment, so there is never a TOFU
    # prompt or a changed-key warning. ./system/runtime.nix installs it from
    # /host, ordered before sshd-keygen, which skips a key that already exists.
    # (An empty list looks tidier and is worse: NixOS then emits an sshd-keygen
    # unit with no ExecStart, which fails on every boot.)
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  # An ocelot keeps no /var/log — the console is the launcher's journal on
  # tempest, which outlives the guest. For that to be true rather than
  # aspirational, warnings and above have to reach the console; the default
  # sends them only to the guest's own journal, unreachable exactly when it
  # matters (sshd down).
  services.journald.extraConfig = ''
    ForwardToConsole=yes
    MaxLevelConsole=warning
  '';

  # The reason an ocelot exists. Not rootless podman: rootless buys nothing
  # inside a guest that is itself the boundary, and the daemon's images are what
  # has to survive a stop (./system/persistence.nix).
  virtualisation.docker.enable = true;

  # fish is irene's shell; NixOS wants it enabled system-wide so it lands in
  # /etc/shells and gets its completions.
  programs.fish.enable = true;

  # A minimum viable Nix rather than ../../modules/nix.nix, which turns on
  # weekly gc and optimise — both actively wrong here. The store is an overlay
  # over a read-only lower, so either pass works against paths the guest does
  # not own: most of what its DB calls valid lives in tempest's store.
  #
  # The writable upper does accumulate, being on the state disk. That is the
  # point, and the eraser is `ocelot destroy`, which drops the disk — an ocelot
  # that has collected more than it is worth is cheaper to rebuild than prune.
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

  # Nothing here holds state a stateVersion bump would migrate: the root is
  # rebuilt every boot and the state disk holds only /home and the docker store.
  system.stateVersion = "25.11";
}
