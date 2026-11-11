# T3 Code's server, so tempest's desktop app (desktop/home-packages.nix) can
# drive agents that run here. The firewall rule and linger that make it
# reachable and start it at boot are in hosts/orchid/system/t3code.nix.
#
# The llm-agents `t3code` wrapper already puts the agent CLIs (claude-code,
# codex, opencode, …) on PATH. `--lan` listens on the LAN and tailnet
# addresses, and the firewall opens the port on tailscale0 only, so in practice
# only the tailnet reaches it. A pairing code gates every new device: run
# `t3 pair` here and open the printed `t3code://pair` link on tempest once.
{
  config,
  inputs,
  pkgs,
  ...
}: let
  t3code = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.t3code;
in {
  # `t3 pair`, `t3 auth session list`, `t3 doctor` against the same ~/.t3.
  home.packages = [t3code];

  systemd.user.services.t3code = {
    Unit.Description = "T3 Code server";
    Service = {
      ExecStart = "${t3code}/bin/t3 serve --lan --no-browser";
      Environment = [
        "T3CODE_PORT=3773"
        # The user manager's default PATH has /etc/profiles/per-user but not
        # standalone home-manager's profile, so agents and their terminals
        # would miss every home.packages tool without this.
        "PATH=${config.home.profileDirectory}/bin:/run/wrappers/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin"
      ];
      Restart = "on-failure";
    };
    Install.WantedBy = ["default.target"];
  };
}
