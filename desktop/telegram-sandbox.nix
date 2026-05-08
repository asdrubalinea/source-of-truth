{ pkgs, lib, ... }:

let
  firejailArgs = [
    "--profile=${pkgs.firejail}/etc/firejail/telegram-desktop.profile"
    "--blacklist=/persist"
    "--blacklist=/root"
    "--novideo"
  ];

  telegramBin = "${pkgs.telegram-desktop}/bin/Telegram";

  firejailInvocation = lib.concatStringsSep " " (
    [ "/run/wrappers/bin/firejail" ] ++ firejailArgs ++ [ "--" telegramBin ]
  );

  telegramSandboxed = pkgs.writeShellScriptBin "telegram-sandboxed" ''
    #!${pkgs.stdenv.shell}
    set -euo pipefail
    exec ${firejailInvocation} "$@"
  '';
in
{
  home.packages = [ telegramSandboxed ];

  xdg.desktopEntries."org.telegram.desktop" = {
    name = "Telegram";
    comment = "New era of messaging";
    icon = "org.telegram.desktop";
    type = "Application";
    terminal = false;
    exec = "${firejailInvocation} -- %U";
    categories = [ "Chat" "Network" "InstantMessaging" "Qt" ];
    mimeType = [ "x-scheme-handler/tg" "x-scheme-handler/tonsite" ];

    settings = {
      TryExec = "/run/wrappers/bin/firejail";
      StartupWMClass = "TelegramDesktop";
      Keywords = "tg;chat;im;messaging;messenger;sms;tdesktop;";
      SingleMainWindow = "true";
      DBusActivatable = "false";
      "X-GNOME-UsesNotifications" = "true";
      "X-GNOME-SingleWindow" = "true";
    };

    actions.quit = {
      name = "Quit Telegram";
      icon = "application-exit";
      exec = "${firejailInvocation} -quit";
    };
  };
}
