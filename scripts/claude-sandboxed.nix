{pkgs, ...}: let
  claudeSandboxed = pkgs.writeShellApplication {
    name = "claude-sandboxed";
    runtimeInputs = with pkgs; [bubblewrap coreutils claude-code];
    text = builtins.readFile ./claude-sandboxed.sh;
  };
in {
  home.packages = [claudeSandboxed];
}
