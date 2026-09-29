# Installer ISO for orchid (and any other disko host): stock minimal installer
# plus flakes, sshd reachable with irene's key, and this repo baked in at
# /etc/source-of-truth — so the install needs neither a push nor a clone.
# Build: nix build .#nixosConfigurations.installer.config.system.build.isoImage
{
  inputs,
  modulesPath,
  pkgs,
  ...
}: {
  imports = ["${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"];

  nix.settings.experimental-features = ["nix-command" "flakes"];

  # The stock ISO ships sshd but doesn't start it; orchid is headless.
  systemd.services.sshd.wantedBy = pkgs.lib.mkForce ["multi-user.target"];
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINvjpybr/+VM1dY75+BkISNz3hzwheDMsr9wiN5Dtsdz irene@orchid"
  ];

  environment.etc."source-of-truth".source = inputs.self;
  environment.systemPackages = [pkgs.git pkgs.nvme-cli];
}
