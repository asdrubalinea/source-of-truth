{ ... }:
{
  # vfio.enable = false;

  # specialisation."VFIO".configuration = {
  #   system.nixos.tags = [ "with-vfio" ];
  #   vfio.enable = true;
  # };

  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [ "irene" ];

  virtualisation = {
    libvirtd = {
      enable = true;
      qemu.swtpm.enable = true;
    };
    spiceUSBRedirection.enable = true;

    docker = {
      enable = true;
      extraOptions = "--data-root=/mnt/docker";
    };
  };
}
