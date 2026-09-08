# What survives a `stop`. The root is tmpfs and rebuilt from the image every
# boot, so this list IS the difference between stop (keeps this) and destroy
# (deletes the state disk). See CONTEXT.md, *Isolation (tempest)*. Short for the
# same reason modules/impermanence-root.nix is: re-derivable state stays out.
{...}: {
  environment.persistence."/state" = {
    enable = true;
    hideMounts = true;

    directories = [
      # The docker layer cache — the one thing whose loss is actually expensive,
      # and the reason /var/lib/docker is not simply left on the tmpfs root.
      "/var/lib/docker"

      # Explicitly owned: as a bare string, impermanence creates the source
      # dir root:root and never enforces ownership, so on a freshly formatted
      # state disk /home/irene comes up unwritable and the first home-manager
      # activation fails. Same trap as in modules/impermanence-root.nix.
      {
        directory = "/home/irene";
        user = "irene";
        group = "users";
        mode = "0700";
      }

      # The other half of the store overlay's upper being on this disk: the
      # upper holds the paths, this holds the record of them being valid, and a
      # pair that doesn't move together is the orphan drift microvm.nix warns
      # about. Without it every boot re-downloads a devshell it already has.
      #
      # Ordering is not incidental: qemu-vm's `register-nix-paths` runs after
      # local-fs.target, which is what impermanence's bind is wanted by — so
      # regInfo lands in the persisted DB, not under it.
      "/nix/var/nix"

      # System uid/gid allocations. irene's uid is pinned in ../users/irene.nix,
      # so this is only sshd/dhcpcd and friends — but without it impermanence
      # warns on every build, and the launcher builds on every start.
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
