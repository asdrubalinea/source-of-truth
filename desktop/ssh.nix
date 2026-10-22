# ssh client config, shared by the tempest and orchid homes.
{...}: {
  programs.ssh = {
    enable = true;
    # Opt out of HM's soon-to-be-removed default `Host *` block; its values
    # just mirror ssh's own built-in defaults.
    enableDefaultConfig = false;

    # `ocelot` writes one stanza per dev VM into ~/.ssh/config.d/ (ADR 0013),
    # which is what makes everything that speaks ssh work by name,
    # `port-forward ocelot-<name> 3000` included. It has to be declared here
    # because HM owns ~/.ssh/config as a store symlink, so nothing can append
    # at runtime. A glob matching nothing is not an error, so this is inert
    # until the first ocelot exists.
    includes = ["config.d/*"];
    settings = {
      # Terminals that set their own TERM (kitty's xterm-kitty, wezterm's
      # wezterm) drop TUI apps to dumb-terminal mode on remote hosts without
      # that terminfo entry — no readline, no arrow keys. sshd always honours
      # the client-sent TERM, so override it to something every host knows.
      # The more specific blocks below still win for their hosts.
      "*" = {
        SetEnv = {
          TERM = "xterm-256color";
        };
      };
      # Port 443 via altssh, so pushes work on networks that firewall 22.
      "gitlab.com" = {
        HostName = "altssh.gitlab.com";
        User = "git";
        Port = 443;
        IPQoS = "none";
      };
      "github.com" = {
        HostName = "ssh.github.com";
        User = "git";
        Port = 443;
        IPQoS = "none";
      };
    };
  };
}
