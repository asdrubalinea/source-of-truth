let
  ids = [
    "1002:73df"
    "1002:ab28"
  ];
in
{ pkgs, lib, config, ... }: {
  options.vfio.enable = with lib;
    mkEnableOption "Configure the machine for VFIO";

  config =
    let cfg = config.vfio;
    in {
      boot = {
        initrd.kernelModules = [
          # "vfio_pci"
          # "vfio"
          # "vfio_iommu_type1"
          # "kvm-amd"
          # "amdgpu"
        ];

        kernelParams = [
          # "amd_iommu=on"
          # "iommu=pt"
          # "video=efifb:off"
        ] ++ lib.optional cfg.enable ("vfio-pci.ids=" + lib.concatStringsSep "," ids);
      };

      hardware.graphics.enable = true;
      virtualisation.spiceUSBRedirection.enable = true;

      environment.systemPackages = with pkgs; [
        virt-manager
        win-virtio
        swtpm
        dconf # needed for saving settings in virt-manager
        libguestfs # needed to virt-sparsify qcow2 files
      ];

      virtualisation.libvirtd = {
        enable = true;
        onBoot = "ignore";
        onShutdown = "shutdown";

        qemu = {
          ovmf = {
            enable = true;
            # packages = with pkgs; [ OVMFFull ];
	    packages = [(pkgs.OVMF.override {
              secureBoot = true;
              tpmSupport = true;
            }).fd];
          };

          swtpm.enable = true;
          runAsRoot = false;
        };
      };
    };
}
