{ pkgs, ... }:

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

  # System service to clean build artifacts and temp files
  systemd.services.nix-deep-clean = {
    description = "Deep clean Nix store and build artifacts";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "nix-deep-clean" ''
        set -euo pipefail

        echo "Starting Nix deep clean..."

        # Clean all user profiles
        echo "Cleaning user profiles..."
        ${pkgs.nix}/bin/nix-collect-garbage --delete-older-than 7d || true

        # Clean root profile
        echo "Cleaning root profile..."
        ${pkgs.sudo}/bin/sudo ${pkgs.nix}/bin/nix-collect-garbage --delete-older-than 7d || true

        # Remove old system profiles
        echo "Removing old system profiles..."
        ${pkgs.sudo}/bin/sudo ${pkgs.nix}/bin/nix-env --profile /nix/var/nix/profiles/system --delete-generations +7 || true

        # Clean build artifacts
        echo "Cleaning build artifacts..."
        rm -rf /tmp/nix-build-* || true

        # Optimize store
        echo "Optimizing Nix store..."
        ${pkgs.nix}/bin/nix-store --optimise || true

        echo "Nix deep clean completed."
      '';
    };
  };

  systemd.timers.nix-deep-clean = {
    description = "Run Nix deep clean weekly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
