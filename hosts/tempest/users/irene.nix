{ pkgs, ... }:
{
  users.users.irene = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "docker"
      "kvm"
      "i2c"
      # Read system-unit journals unprivileged (waybar backup badge click →
      # `journalctl -xeu borgbackup-job-…`; see rices/niri/waybar).
      "systemd-journal"
    ];

    hashedPassword = (import ../../../passwords).password;
    shell = pkgs.fish;

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINvjpybr/+VM1dY75+BkISNz3hzwheDMsr9wiN5Dtsdz irene@orchid"
    ];
  };
}
