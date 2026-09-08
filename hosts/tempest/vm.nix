# VM-only layer for the `tempest-vm` configuration (virtual = true).
#
# disko's `vmWithDisko` formats a throwaway disk from the same disks/tempest.nix
# spec and boots an ephemeral overlay on top, so the filesystem layout is real
# while the host nix store is shared in and the build stays fast.
#
#   ./build-vm tempest   then   ./result/bin/disko-vm
#
# There is no enrolled TPM2 here, so the initrd prompts for the LUKS password:
# it is **disko**, disko's non-interactive default. Every dataset starts empty,
# so it's a fresh tempest with no personal files.
{
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../../modules/vm-first-boot.nix
  ];

  # disko maps this to memorySize; its 1024 MB default is far too small for a
  # niri desktop.
  disko.memSize = 8192;

  # disks/tempest.nix creates the LVs alphabetically, so `root` (95%FREE) claims
  # its share before `swap` (fixed 40 GiB) — leaving only 5% for swap. On the
  # real NVMe that's ~50 GiB and fits; on a small VM disk it doesn't. So the
  # virtual disk just has to be big enough that 5% still exceeds 40 GiB (≳ 804
  # GiB). qcow2 is sparse, so this is only a logical ceiling and the result
  # image stays small. Used ONLY by the image builder.
  disko.devices.disk.main.imageSize = "1024G";

  # The virtualisation.* options only exist inside the eval disko extends with
  # qemu-vm.nix, so setting them at top level errors — guest tuning has to route
  # through here.
  disko.tests.extraConfig = {
    # A niri desktop + xwayland + noctalia + the virgl render thread is cramped
    # on 4; 8 keeps the 16-thread host responsive too.
    virtualisation.cores = 8;

    # impermanence needs every filesystem backing /persist to be neededForBoot.
    # The real host asserts this on `fileSystems.*`, but disko's VM re-emits the
    # layout through `virtualisation.fileSystems`, which drops the flag — so
    # re-assert it or the bind-mounts don't come up in the initrd.
    virtualisation.fileSystems = {
      "/persist".neededForBoot = true;
      "/persist/home".neededForBoot = true;
    };

    # niri needs a GL-capable GPU and x86 qemu-vm adds none. blob resources
    # (QEMU 10+) let virgl map guest buffers out of shared host memory instead
    # of copying every frame, which needs a memfd backend — and its size MUST
    # equal `-m` (8G) or QEMU refuses to start. Appending `-machine` here
    # augments qemu-vm's own accel line rather than replacing it. venus (Vulkan)
    # is omitted deliberately: niri composites through smithay's GLES path.
    #
    # If the VM fails to launch, revert this block to a bare
    # `-device virtio-vga-gl` (or use sdl/software GL if the host QEMU lacks
    # GTK/virgl).
    virtualisation.qemu.options = [
      "-vga none"
      "-object"
      "memory-backend-memfd,id=mem0,size=8G,share=on"
      "-machine"
      "memory-backend=mem0"
      "-device"
      "virtio-vga-gl,blob=true,hostmem=4G"
      "-display"
      "gtk,gl=on"
    ];
  };

  # Real tempest runs HM standalone; here it's a NixOS module so one build
  # produces a configured image. The home config is still single-sourced from
  # homes/tempest. niri's HM module is auto-wired into every HM user by
  # niri.nixosModules.niri in this form, so it must NOT be added to
  # sharedModules again — that double-declares the options.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
      hostname = "tempest";
    };
    users.irene = {
      imports = [../../homes/tempest];

      # stylix sets nixpkgs.overlays inside the HM config, which trips HM's
      # deprecation warning under useGlobalPkgs (a future bump makes it an
      # error). Those overlays are ignored here anyway — the VM uses system
      # pkgs — so this is cosmetic. The real laptop runs standalone, so it
      # never sees this override.
      stylix.overlays.enable = false;

      # Every animated frame goes through the emulated virgl path, the most
      # visible source of jank in the VM. Off here only.
      programs.niri.settings.animations.enable = lib.mkForce false;
    };

    # Back up rather than abort if /etc/skel seeded a file HM also manages —
    # otherwise the very first activation can fail on a collision.
    backupFileExtension = "hm-bak";
  };

  # Rule: only override what CANNOT work in the VM and would spam the journal
  # with failed retries. Everything else from the shared layer is left running
  # on purpose — it works against the VM's real ZFS pool, which is exactly what
  # the clone exists to test.
  services.smartd.enable = lib.mkForce false; # monitors /dev/nvme0n1, absent here
  # No SSH key or remote repo here, so the daily job would just fail on schedule.
  systemd.services.borgbackup-job-home-irene.enable = lib.mkForce false;
  systemd.timers.borgbackup-job-home-irene.enable = lib.mkForce false;
}
