# VM-only layer for the `tempest-vm` configuration (virtual = true).
#
# This VM reproduces tempest's EXACT filesystem: it is built with disko's
# `vmWithDisko`, which formats a throwaway virtual disk from the same
# disks/tempest.nix spec (GPT + LUKS + LVM + swap + ZFS rpool/{nix,persist,
# persist/home,sbctl,reserved} + tmpfs root + impermanence) and then boots an
# ephemeral overlay on top. The host nix store is shared in (copyNixStore=false,
# mountHostNixStore=true), so the layout is real but the build stays fast.
#
# Build & run:
#   nix build '.#nixosConfigurations.tempest-vm.config.system.build.vmWithDisko'
#   ./result/bin/disko-vm
#
# At boot the LUKS volume must be unlocked. There is no enrolled TPM2 in the VM,
# so the initrd prompts on the console — the test image is formatted with the
# password **disko** (disko's non-interactive default; see disko lib/types/luks.nix).
# Everything under the ZFS datasets starts empty, so it's a fresh tempest with no
# personal files; home-manager populates /home/irene (a bind-mount of the empty
# rpool/persist/home dataset) on first boot.
{ inputs, lib, pkgs, ... }:
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  # Guest sizing. disko's interactive-vm maps disko.memSize -> memorySize; the
  # default (1024 MB) is far too small for a niri desktop. (memSize is a real
  # top-level disko option and is inherited by the VM eval.)
  disko.memSize = 8192;

  # disks/tempest.nix creates the LVs in alphabetical order: `root` (95%FREE)
  # before `swap` (fixed 40 GiB). So root claims 95% of the whole VG and only 5%
  # is left for swap. On the real ~1 TB NVMe that 5% is ~50 GiB (> 40), so it
  # works; on a small VM disk swap won't fit ("insufficient free space"). To keep
  # the layout EXACTLY as-is, the virtual disk just has to be large enough that
  # 5% still exceeds 40 GiB — i.e. ≳ 804 GiB. 1 TiB gives ~51 GiB of headroom.
  # qcow2 is sparse, so this is only a logical ceiling: ZFS and swap write just
  # headers/metadata, so the actual result image stays small. imageSize is used
  # ONLY by the image builder; the real laptop install is unaffected.
  disko.devices.disk.main.imageSize = "1024G";

  # The QEMU/virtualisation options only exist inside the eval that disko extends
  # with qemu-vm.nix for `vmWithDisko` (see disko module.nix: vmVariantWithDisko =
  # extendModules { modules = [ interactive-vm.nix config.disko.tests.extraConfig ]; }).
  # Setting them at top level errors ("virtualisation.cores does not exist"), so
  # route guest tuning through disko.tests.extraConfig.
  disko.tests.extraConfig = {
    virtualisation.cores = 4;

    # impermanence requires every filesystem backing /persist to be
    # neededForBoot. On the real host system/persistence.nix asserts this on
    # `fileSystems.*`, but disko's VM re-emits the layout through
    # `virtualisation.fileSystems` (qemu-vm.nix: `fileSystems = mkVMOverride
    # virtualisation.fileSystems`), which drops that flag. Re-assert it on the
    # VM's filesystems so the bind-mounts come up in the initrd.
    virtualisation.fileSystems = {
      "/persist".neededForBoot = true;
      "/persist/home".neededForBoot = true;
    };

    # niri needs a GL-capable GPU; x86 qemu-vm adds none by default. virtio-vga-gl
    # + a gtk/GL display gives accelerated rendering. Adjust if your host QEMU
    # lacks GTK/virgl (e.g. "-display sdl,gl=on", or software GL).
    virtualisation.qemu.options = [
      "-vga none"
      "-device virtio-vga-gl"
      "-display gtk,gl=on"
    ];
  };

  # Real tempest runs home-manager standalone; here we attach it as a NixOS
  # module so a single build produces a fully-configured image. The home config
  # itself is still single-sourced from homes/tempest. niri's HM module
  # (programs.niri.*) is auto-wired into every HM user by niri.nixosModules.niri
  # when home-manager runs as a NixOS module, so it must NOT be added to
  # sharedModules again here (that double-declares the options).
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
      hostname = "tempest";
    };
    users.irene = {
      imports = [ ../../homes/tempest ];

      # stylix enables `stylix.overlays.enable` by default, which sets
      # nixpkgs.overlays inside the HM config. Combined with useGlobalPkgs that
      # trips HM's "nixpkgs.config/overlays + useGlobalPkgs" deprecation warning
      # ("will soon not be possible" → a future HM bump makes it an error). Under
      # useGlobalPkgs those HM-set overlays are ignored anyway (the VM uses the
      # system pkgs), so the themed packages were never applied here — disabling
      # is purely cosmetic in the VM and clears the warning. The real laptop runs
      # HM standalone (no useGlobalPkgs), so this override never touches it.
      stylix.overlays.enable = false;
    };

    # Don't abort activation if /etc/skel seeded a file HM also manages — back it
    # up instead. Otherwise the very first activation can fail on a collision and
    # leave the home unconfigured.
    backupFileExtension = "hm-bak";
  };

  # home-manager activates via home-manager-irene.service, but the NixOS module
  # only orders it `after nix-daemon.socket` — NOT after impermanence binds
  # /persist/home/irene over /home/irene (a systemd `home-irene.mount` unit). So
  # on first boot HM writes into the pre-bind directory and the bind then masks
  # everything, which is why the home looks empty until a manual `home-manager
  # switch` (by then the mount is up). RequiresMountsFor makes systemd pull in
  # and order after the bind mount, so activation lands in the persisted home and
  # the desktop comes up fully configured on first boot.
  systemd.services.home-manager-irene = {
    unitConfig.RequiresMountsFor = "/home/irene";
    # /home/irene lives on the persist ZFS dataset; make sure it's mounted.
    after = [ "home-irene.mount" ];
    requires = [ "home-irene.mount" ];
  };

  # Declaratively seed the (public) flake into /persist (a real ZFS dataset in
  # this VM) so `nh` / config-apply paths resolve exactly like the real host.
  # Idempotent: ConditionPathExists skips the clone if the tree already exists.
  # This module is only imported when virtual = true, so it can never touch the
  # real laptop's /persist.
  systemd.services.seed-source-of-truth = {
    description = "Clone source-of-truth into /persist";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.git ];
    unitConfig = {
      ConditionPathExists = "!/persist/source-of-truth/.git";
      # Retry a handful of times: network-online.target can fire before DNS/egress
      # is actually usable, and without this a single early failure would leave
      # /persist/source-of-truth absent for the whole boot (programs.nh.flake then
      # has no flake). Stop after StartLimitBurst tries so a genuinely offline VM
      # doesn't loop forever.
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };
    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      RestartSec = 15;
      # Clean up a half-finished clone so the retry starts from a clean slate
      # (git clone refuses a non-empty target).
      ExecStartPre = "${pkgs.coreutils}/bin/rm -rf /persist/source-of-truth";
      ExecStart =
        "${pkgs.git}/bin/git clone "
        + "https://github.com/asdrubalinea/source-of-truth /persist/source-of-truth";
    };
  };

  # Rule: only override services that CANNOT work in the VM and would otherwise
  # spam the journal with failed retries (missing hardware / no backup target).
  # Everything else from the shared layer (vaultwarden, caddy, tailscale, keyd,
  # flatpak, sanoid, …) is left running on purpose — it works against the VM's
  # real ZFS pool and is exactly the system behaviour the clone exists to test.
  services.smartd.enable = lib.mkForce false; # monitors /dev/nvme0n1, absent here
  services.framework-control.enable = lib.mkForce false; # laptop embedded controller
  # borg has no SSH key / remote repo in the VM, so the daily job + timer would
  # just fail on schedule.
  systemd.services.borgbackup-job-home-irene.enable = lib.mkForce false;
  systemd.timers.borgbackup-job-home-irene.enable = lib.mkForce false;
}
