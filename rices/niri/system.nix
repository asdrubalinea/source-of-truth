{ inputs, pkgs, ... }:
{
  imports = [
    ./fonts.nix
  ];

  programs = {
    niri = {
      enable = true;
      # Must be set explicitly. niri-flake's module default is
      # `(make-package-set pkgs).niri-stable`, which reaches past the
      # niriPrebuiltOverlay aliases in flake.nix and compiles niri against our
      # nixpkgs — a local Rust build that no cache can serve. pkgs.niri-unstable
      # is the alias to niri-flake's own prebuilt output.
      #
      # This is the compositor greetd launches (`niri-session` ships inside this
      # package), so every `niri msg` in the rice must come from the same
      # derivation — a version mismatch prints a banner instead of JSON and
      # silently breaks the `--json` consumers. See rices/niri/niri.nix.
      package = pkgs.niri-unstable;
    };
    fish.enable = true;
  };

  # Noctalia's battery readout polls upowerd over D-Bus; without the daemon the
  # battery widget stays blank. The v5 NixOS docs list this as a required option
  # for the battery/wifi/bluetooth/power-profile features
  # (https://docs.noctalia.dev/v5/getting-started/nixos/). networkmanager and
  # bluetooth are already on at the host level; power-profiles-daemon is the one
  # feature we deliberately can't satisfy — tempest runs TLP (hardware/framework-
  # tlp-advanced.nix forces power-profiles-daemon off, the two are mutually
  # exclusive), so Noctalia's power-profile control is inert here by design.
  services.upower.enable = true;

  # swaylock is the runtime locker (rices/niri/swayidle.nix `lock` + before-sleep).
  # Like every unprivileged Wayland locker it needs its own PAM service to unlock:
  # the default config gives it standard unix auth via the setuid unix_chkpwd
  # helper (plus fingerprint when fprintd is enabled). Without it, unlocking fails.
  security.pam.services.swaylock = { };

  # Noctalia's lockscreen authenticates via PAM. It defaults to the `login`
  # service (LockContext.qml: NOCTALIA_PAM_SERVICE || "login"), but `login`
  # expects a privileged caller — an unprivileged locker fails its account stage
  # with "pam_unix(login:account): setuid failed: Operation not permitted", so
  # unlocking never succeeds. Give it a dedicated, minimal PAM service instead
  # (standard unix auth via the setuid unix_chkpwd helper, plus fingerprint when
  # fprintd is enabled) and point NOCTALIA_PAM_SERVICE at it (set in the niri
  # environment block, rices/niri/niri.nix). This mirrors what swaylock/hyprlock
  # do. Kept even though swaylock now owns the lock path, so Noctalia's own lock
  # IPC (if ever invoked) still authenticates rather than dead-locking on `login`.
  security.pam.services.noctalia = { };
}
