{ config, pkgs, ... }:

# Email: mu4e + mbsync (isync) + msmtp.
# Two accounts: fastmail (primary) and pec (Italian PEC, @pec.it = Aruba PEC).
#
# Credential setup (one-time):
#   1. Fastmail app password: https://app.fastmail.com/settings/security/devicekeys
#      → install -m 600 /dev/null ~/.config/mail/fastmail-password
#        and paste it (no trailing newline).
#   2. PEC password: the mailbox password from PEC.it webmail. If 2FA is
#      enabled on the PEC account you must generate a dedicated client
#      password from the PEC.it webmail settings (the regular password
#      will be rejected). Also confirm IMAP is enabled in webmail prefs.
#      → install -m 600 /dev/null ~/.config/mail/pec-password
#        and paste it (no trailing newline).
#   3. Rebuild, then run:
#        mbsync -a
#        mu init --maildir=~/Mail \
#                --my-address=hi@irene.foo \
#                --my-address=asdrubalini@pec.it
#        mu index
#
# To migrate creds to pass / sops / GPG later, change only `passwordCommand`.
# Hosts below are the documented Aruba PEC defaults
# (https://guide.pec.it/.../configurare-casella-pec-programma-posta.aspx).

{
  programs.mbsync.enable = true;
  programs.msmtp.enable = true;
  programs.mu.enable = true;

  accounts.email.maildirBasePath = "Mail";

  accounts.email.accounts.fastmail = {
    primary = true;
    address = "hi@irene.foo";
    realName = "Irene Lena";
    userName = "hi@irene.foo";

    imap = {
      host = "imap.fastmail.com";
      port = 993;
      tls.enable = true;
    };
    smtp = {
      host = "smtp.fastmail.com";
      port = 465;
      tls.enable = true;
    };

    passwordCommand =
      "cat ${config.home.homeDirectory}/.config/mail/fastmail-password";

    mbsync = {
      enable = true;
      create = "maildir";
      expunge = "both";
    };
    msmtp.enable = true;
    mu.enable = true;
  };

  accounts.email.accounts.pec = {
    address = "asdrubalini@pec.it";
    realName = "Irene Lena";
    userName = "asdrubalini@pec.it";

    imap = {
      host = "imaps.pec.aruba.it";
      port = 993;
      tls.enable = true;
    };
    smtp = {
      host = "smtps.pec.aruba.it";
      port = 465;
      tls.enable = true;
    };

    passwordCommand =
      "cat ${config.home.homeDirectory}/.config/mail/pec-password";

    mbsync = {
      enable = true;
      create = "maildir";
      expunge = "both";
    };
    msmtp.enable = true;
    mu.enable = true;
  };
}
