{ pkgs, ... }:

let
  hashedPassword = "$6$BkMgWYEIITYDhZkR$KnfSasOiuqi14e.85Ft/YMjgxoniRxoYXc8Tbk1J4ksq2I8Hk358V2OQFcRqHmBv/g52nhCOUWvb3uzjQuMbF0";
in
{
  users.users.irene = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "docker"
      "kvm"
    ];
    inherit hashedPassword;
    shell = pkgs.fish;
  };
}
