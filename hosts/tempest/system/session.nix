{ pkgs, ... }:
{
  # Login / session manager for the niri desktop.
  #
  # tempest auto-unlocks its LUKS root via TPM2 (no boot password), so login is
  # the only auth boundary. greetd's `initial_session` autologins irene straight
  # into `niri-session` on every greetd start — including after a
  # `systemctl soft-reboot`, which is the whole point: a soft-reboot drops you
  # back into niri hands-free.
  #
  # That autologin would also fire on a *cold* boot (where there was no auth at
  # all, thanks to TPM), so the niri rice gates it behind the noctalia
  # lockscreen: a startup guard locks the session unless SoftRebootsCount >= 1
  # (i.e. unless this came from a soft-reboot). See homes/tempest/soft-reboot.nix
  # and docs/adr/0007-niri-soft-reboot-session.md.
  #
  # `default_session` (tuigreet) is the greeter shown only when you log out.
  # Enabling greetd is also what finally makes the
  # `security.pam.services.greetd.enableGnomeKeyring` line in security.nix do
  # anything — it unlocks the login keyring as part of the greetd PAM session.
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "niri-session";
        user = "irene";
      };
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
        user = "greeter";
      };
    };
  };
}
