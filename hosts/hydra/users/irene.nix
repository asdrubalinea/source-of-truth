{ pkgs, ... }:
{
  users = {
    mutableUsers = false;

    users.root.hashedPassword = (import ../../../passwords).password;

    users.irene = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPassword = (import ../../../passwords).password;
      shell = pkgs.fish;

      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINvjpybr/+VM1dY75+BkISNz3hzwheDMsr9wiN5Dtsdz irene@orchid"
      ];
    };
  };
}
