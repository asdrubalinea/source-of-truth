# What survives a `stop`. The root filesystem is tmpfs and is rebuilt from the
# image on every boot, so this list is the whole difference between stop (ends
# the machine, keeps this) and destroy (deletes the state disk). See CONTEXT.md,
# *Isolation (tempest)*.
#
# Same idiom as ../../../modules/impermanence-root.nix, and short for the same
# reason it is short there: state that is re-derivable does not belong here.
{...}: {
  environment.persistence."/state" = {
    enable = true;
    hideMounts = true;

    directories = [
      # The docker layer cache — the one thing whose loss is actually expensive,
      # and the reason /var/lib/docker is not simply left on the tmpfs root.
      "/var/lib/docker"

      # The guest's own home. Explicitly owned: as a bare string impermanence
      # creates the source dir root:root and never enforces ownership, so on a
      # freshly formatted state disk /home/irene comes up unwritable and the
      # first home-manager activation fails. (The same trap is documented at
      # length in modules/impermanence-root.nix.)
      {
        directory = "/home/irene";
        user = "irene";
        group = "users";
        mode = "0700";
      }

      # The Nix database, and the profiles and gcroots beside it. This is the
      # other half of the store overlay's upper being on this disk (../default.nix):
      # the upper holds the paths, this holds the record of them being valid, and
      # a pair that does not move together is the orphan drift microvm.nix warns
      # about. Without it every boot re-downloads a devshell it already has.
      #
      # Ordering is not incidental: qemu-vm's `register-nix-paths` loads the
      # guest's own closure into the DB and is `after = local-fs.target`, which
      # is what impermanence's bind is wanted by — so regInfo lands in the
      # persisted DB, not under it.
      "/nix/var/nix"

      # The system users' uid/gid allocations. irene's uid is pinned in
      # ../users/irene.nix, so this is only about sshd, dhcpcd and friends — but
      # without it impermanence warns on every single build of this guest, and
      # the launcher builds on every start.
      "/var/lib/nixos"
    ];

    files = [
      "/etc/machine-id"
    ];

    # Deliberately not here:
    #   /etc/ssh/ssh_host_* — generated on tempest and installed from /host at
    #     every boot (./runtime.nix), so tempest can seed known_hosts at creation
    #     time without ever mounting this image.
    #   /var/log — the console goes to the launcher's journal on tempest, which
    #     outlives the guest and is where a failed boot is actually read.
  };
}
