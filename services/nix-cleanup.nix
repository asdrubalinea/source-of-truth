{ ... }:

{
  # Automatic Nix store garbage collection
  nix.gc = {
    automatic = true;
    # Run weekly (every 7 days)
    dates = "weekly";
    # Delete generations older than 7 days
    options = "--delete-older-than 7d";
    # Run as root
    persistent = true;
  };

  # Optimize Nix store after garbage collection
  nix.optimise = {
    automatic = true;
    # Run weekly after garbage collection
    dates = [ "weekly" ];
  };
}
