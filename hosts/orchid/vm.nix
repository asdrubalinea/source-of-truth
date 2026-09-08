# VM-only layer for the `orchid-vm` configuration (virtual = true).
#
# Same idea as hosts/tempest/vm.nix: disko's `vmWithDisko` formats a throwaway
# disk from disks/orchid.nix and boots an ephemeral overlay on top, with the
# host store shared in.
#
#   ./build-vm orchid   then   ./result/bin/disko-vm
#
# The initrd prompts for the LUKS passphrase on the console — no enrolled TPM2
# here, and the test image's password is **disko**, disko's non-interactive
# default. Console-only, since orchid is headless: no GPU/display tuning.
{
  inputs,
  lib,
  pkgs,
  config,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../../modules/vm-first-boot.nix
  ];

  # No desktop to feed, and ZFS' ARC is capped at 16 GiB by system/zfs.nix — which
  # is a cap, not a reservation, so a small guest is fine. 4 GiB is enough to boot,
  # import the pool and run the services.
  disko.memSize = 4096;

  # Alphabetical LV order puts `root` (95%FREE) before `swap` (16 GiB), so swap
  # must fit in the remaining 5% — the disk has to be ≳ 320 GiB or the format
  # fails with "insufficient free space". qcow2 is sparse, so this is only a
  # logical ceiling. Used ONLY by the image builder.
  disko.devices.disk.main.imageSize = "512G";

  # The QEMU/virtualisation options only exist inside the eval that disko extends
  # with qemu-vm.nix for `vmWithDisko`, so guest tuning has to be routed through
  # disko.tests.extraConfig rather than set at top level.
  disko.tests.extraConfig = {
    virtualisation.cores = 4;

    # Headless, so run on the serial console in the launching terminal — which
    # also sets console=ttyS0, putting the initrd's LUKS prompt and the boot log
    # on stdout. Ctrl-a x kills the VM.
    virtualisation.graphics = false;

    # A software TPM, because the config assumes the real tower's: systemd-creds
    # (used by libvirt's virt-secret-init-encryption.service) refuses to derive a
    # key with no TPM2 when its host key would live on a temporary filesystem —
    # precisely a tmpfs root. Without this the VM fails that unit every boot for
    # a reason the real host does not have.
    virtualisation.tpm.enable = true;

    # impermanence needs every filesystem backing /persist to be neededForBoot.
    # modules/impermanence-root.nix asserts that on `fileSystems.*`, but disko's
    # VM re-emits the layout through `virtualisation.fileSystems`, which drops
    # the flag — re-assert it or the bind-mounts never come up in the initrd.
    virtualisation.fileSystems = {
      "/persist".neededForBoot = true;
      "/persist/home".neededForBoot = true;
    };
  };

  # Real orchid runs home-manager standalone; here it is attached as a NixOS
  # module so one build produces a fully-configured image. The home config itself
  # is still single-sourced from homes/orchid.nix.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
      hostname = "orchid";
    };
    users.irene.imports = [../../homes/orchid.nix];

    # Don't abort activation if /etc/skel seeded a file HM also manages — back it
    # up instead, or the very first activation can fail on a collision.
    backupFileExtension = "hm-bak";
  };

  # There is no interactive way in: both hashes come from ./passwords
  # (git-crypt), which a throwaway test run has no business unlocking, and
  # openssh only accepts keys. So the guest prints its own failure surface to the
  # serial console once the boot settles — the entire reason for booting it.
  systemd.services.vm-boot-report = {
    description = "Print failed units to the console after boot";
    wantedBy = ["multi-user.target"];
    after = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
    script = ''
      sleep 20   # let the stragglers fail before taking the census
      echo "===== BOOT REPORT: systemctl --failed"
      ${config.systemd.package}/bin/systemctl --failed --no-legend --plain || true
      for u in $(${config.systemd.package}/bin/systemctl --failed --no-legend --plain | ${pkgs.gawk}/bin/awk '{print $1}'); do
        echo "===== BOOT REPORT: journal for $u"
        ${config.systemd.package}/bin/journalctl -b -u "$u" --no-pager -n 20 || true
      done
      echo "===== BOOT REPORT: end"
    '';
  };

  # Same rule as tempest-vm: override only what CANNOT work here and would spam
  # the journal with failed retries. Everything else from the shared layer is
  # left running on purpose — it works against the VM's real ZFS pool, which is
  # what this clone exists to test.
  services.smartd.enable = lib.mkForce false; # monitors /dev/nvme0n1, absent here

  # Everything below needs a credential that only exists on the real host:
  #   borg      → /home/irene/.ssh/id_ed25519 + /persist/borg-*/passphrase
  #   caddy     → /persist/caddy/env (Cloudflare DNS token; ACME would fail anyway)
  #   the bots  → /persist/{diapee-bot,auxologico-check}/env
  services.borg-backup.enable = lib.mkForce false;
  services.caddy.enable = lib.mkForce false;
  services.diapee-bot.enable = lib.mkForce false;
  services.auxologico-check.enable = lib.mkForce false;

  # Pushes a vault snapshot to the mirrors over SSH as vwbackup@; no key here, and
  # the VM must never write to the real hosts anyway.
  systemd.timers.vaultwarden-export-snapshot.enable = lib.mkForce false;
  systemd.services.vaultwarden-export-snapshot.enable = lib.mkForce false;
}
