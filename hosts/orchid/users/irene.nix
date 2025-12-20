{ pkgs, ... }:
{
  users = {
    mutableUsers = false;
    extraUsers.root.hashedPassword = (import ../../../passwords).password;

    users."irene" = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "libvirtd"
        "docker"
        "jackaudio"
        "render"
        "video"
      ];
      hashedPassword = (import ../../../passwords).password;
      shell = pkgs.fish;
    };
  };
}
