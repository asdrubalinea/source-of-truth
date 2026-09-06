{pkgs, ...}: {
  users = {
    # Nothing here is edited from inside: the root is rebuilt every boot, so a
    # user added with useradd would vanish anyway.
    mutableUsers = false;

    users.irene = {
      isNormalUser = true;
      # Pinned rather than allocated, so the ownership of everything already on
      # a state disk keeps matching after any change to this file. It is also
      # what makes /var/lib/nixos not worth persisting (../system/persistence.nix).
      uid = 1000;
      extraGroups = ["wheel" "docker"];
      shell = pkgs.fish;

      # No password. An ocelot is entered over ssh with a key and has no console
      # login; modules/security.nix makes wheel passwordless for doas and sudo-rs
      # both, which is the right posture for a blast-radius boundary (CONTEXT.md).
      hashedPassword = null;

      # Same inline convention as hosts/*/users/irene.nix — this is tempest's
      # own key, and tempest is the only thing that can reach the forwarded port.
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINvjpybr/+VM1dY75+BkISNz3hzwheDMsr9wiN5Dtsdz irene@orchid"
      ];
    };
  };
}
