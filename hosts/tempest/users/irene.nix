{ pkgs, ... }:
{
  users.users.irene = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "docker"
      "kvm"
    ];

    hashedPassword = (import ../../../passwords).password;
    shell = pkgs.fish;
  };
}
