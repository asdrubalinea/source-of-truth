# System half of the T3 Code server in homes/orchid/t3code.nix.
{...}: {
  # Tailnet only, as with llama-server (system/llm.nix): the LAN stays closed.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [3773];

  # Start irene's user manager at boot, so the server is up without a login.
  users.users.irene.linger = true;
}
