{...}: {
  # Privilege escalation, shared by every host. This was four copies under
  # hosts/*/system/security.nix — tempest/orchid byte-identical apart from one
  # line, hydra/zephyr byte-identical to each other.
  #
  # doas is the daily driver; sudo stays enabled (as sudo-rs) because scripts and
  # third-party tooling shell out to `sudo` unconditionally. Both passwordless
  # for wheel: this is a single-user machine set and the disk is already behind
  # LUKS, so a sudo password only protects against someone already at an unlocked
  # session.
  #
  # Deliberately NOT shared, because both change behaviour rather than state
  # policy:
  #   - doas extraRules with keepEnv (hydra/zephyr keep their own file for it) —
  #     wheelNeedsPassword already covers noPass, so keepEnv is the only real
  #     effect, and it is not something to switch on for the desktops silently.
  #   - security.pam.services.greetd.enableGnomeKeyring (tempest only), which now
  #     lives next to the greetd config in hosts/tempest/system/session.nix.
  security = {
    doas = {
      enable = true;
      wheelNeedsPassword = false;
    };

    # Note: options go on sudo-rs, not sudo. Enabling sudo-rs sets
    # `security.sudo.enable = mkDefault false` (and asserts the two can't both be
    # on), so anything set under `security.sudo` is silently dead config.
    sudo-rs = {
      enable = true;
      execWheelOnly = true;
      wheelNeedsPassword = false;
    };
  };
}
