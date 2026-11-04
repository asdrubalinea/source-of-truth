{pkgs, ...}: let
  # mmsg / niri come from the running compositor's own PATH, not from here.
  claudeNotify = pkgs.writeShellApplication {
    name = "claude-notify";
    runtimeInputs = with pkgs; [coreutils jq libnotify util-linux];
    text = builtins.readFile ./claude-notify.sh;
  };
in {
  home.packages = [claudeNotify];
}
