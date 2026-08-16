{ ... }:
# The NixOS half of the ember rice's *furniture* — the parts every compositor
# layer needs, whichever one you log into. The compositors themselves are enabled
# from ./compositors/<name>/system.nix, imported alongside this one by the host.
#
# Standalone Home Manager can't set NixOS options, so the rice is wired in two
# halves: this file (imported by hosts/tempest/default.nix) and the home half
# (imported by homes/tempest/default.nix). See ADR 0004.
{
  imports = [
    ./fonts.nix
  ];

  programs.fish.enable = true;

  # Noctalia's battery readout polls upowerd over D-Bus; without the daemon the
  # battery widget stays blank. The v5 NixOS docs list this as a required option
  # for the battery/wifi/bluetooth/power-profile features
  # (https://docs.noctalia.dev/v5/getting-started/nixos/). networkmanager and
  # bluetooth are already on at the host level; power-profiles-daemon is the one
  # feature we deliberately can't satisfy — tempest runs TLP (hardware/framework-
  # tlp-advanced.nix forces power-profiles-daemon off, the two are mutually
  # exclusive), so Noctalia's power-profile control is inert here by design.
  services.upower.enable = true;

  # swaylock is the runtime locker (rices/ember/swayidle.nix `lock` + before-sleep).
  # Like every unprivileged Wayland locker it needs its own PAM service to unlock:
  # the default config gives it standard unix auth via the setuid unix_chkpwd
  # helper (plus fingerprint when fprintd is enabled). Without it, unlocking fails.
  # Furniture, not compositor: swayidle/swaylock run under either session.
  security.pam.services.swaylock = { };

  # Noctalia's lockscreen authenticates via PAM. It defaults to the `login`
  # service (LockContext.qml: NOCTALIA_PAM_SERVICE || "login"), but `login`
  # expects a privileged caller — an unprivileged locker fails its account stage
  # with "pam_unix(login:account): setuid failed: Operation not permitted", so
  # unlocking never succeeds. Give it a dedicated, minimal PAM service instead
  # (standard unix auth via the setuid unix_chkpwd helper, plus fingerprint when
  # fprintd is enabled) and point NOCTALIA_PAM_SERVICE at it — which each
  # compositor layer does in its own environment block, since that is the one
  # place an env var can be set per session. This mirrors what swaylock/hyprlock
  # do. Kept even though swaylock now owns the lock path, so Noctalia's own lock
  # IPC (if ever invoked) still authenticates rather than dead-locking on `login`.
  security.pam.services.noctalia = { };
}
