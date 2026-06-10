{ pkgs, ... }:
{
  programs.fish.enable = true;

  # No local config-apply wrapper: deploys are remote. tempest builds the
  # closure (binfmt aarch64 + cache) and pushes it with
  #   nixos-rebuild switch --flake .#zephyr \
  #     --target-host irene@zephyr --build-host localhost
  # so zephyr itself never compiles. These are just the basics for poking around
  # over SSH.
  environment.systemPackages = with pkgs; [
    git
    helix
    htop
    tailscale
  ];

  environment.variables = {
    EDITOR = "${pkgs.helix}/bin/hx";
  };
}
