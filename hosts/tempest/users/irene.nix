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
    ];

    hashedPassword = (import ../../../passwords).password;
    shell = pkgs.fish;
  };
}
