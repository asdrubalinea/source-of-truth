{
  # Plays on the win11 VM: picks "Windows 11" at the greeter
  # (system/gaming-vm.nix), whose session reaches qemu:///system through the
  # libvirtd group. No home-manager config and no impermanence bind, so
  # /home/camilla is tmpfs and starts empty every boot; nothing she runs on
  # the host needs to keep state.
  #
  # The password hash lives out of the repo (mutableUsers = false, so it is
  # read at activation; missing file = locked account). Set it with:
  #   mkpasswd | doas tee /persist/secrets/camilla.passwd
  users.users.camilla = {
    isNormalUser = true;
    extraGroups = ["libvirtd"];
    hashedPasswordFile = "/persist/secrets/camilla.passwd";
  };
}
