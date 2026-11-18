{
  config,
  lib,
  pkgs,
  ...
}: let
  pt = import ./passthrough-vm.nix {inherit config lib pkgs;};

  # One desktop VM per BSD, each on the 9070 XT and the chipset USB controller
  # and started from its own greeter entry. Only one of these and win11 runs
  # at a time. Setup and use: docs/bsd-vms.md.
  vms = [
    {
      name = "openbsd";
      label = "OpenBSD";
      uuid = "6d1e708b-2c41-4a6b-af8c-cf3ebe4cb7f1";
      mac = "52:54:00:0b:5d:01";
      ip = "192.168.122.10";
    }
    {
      name = "freebsd";
      label = "FreeBSD";
      uuid = "48d5af96-8304-4081-8482-055858a50694";
      mac = "52:54:00:0b:5d:02";
      ip = "192.168.122.11";
    }
  ];

  mkVm = {
    name,
    label,
    uuid,
    mac,
    # Fixed by a DHCP reservation in the define service, so the host always
    # finds the guest here, tailscale or not.
    ip,
  }: let
    dir = "/var/lib/vms/${name}";
    disk = "${dir}/disk.raw";
    # Sparse, so only what the guest writes takes space on rpool.
    diskSize = "256G";
    installIso = "/var/lib/vms/iso/${name}.iso";

    # Same shape as win11 (./gaming-vm.nix): the 9070 XT and the chipset USB
    # controller, cores 1-7 pinned. What differs is what a BSD can use: no
    # Hyper-V enlightenments (both would attach their Hyper-V drivers and look
    # for a VMBus), KVM's paravirtual clock instead, a UTC clock, no TPM, no
    # Secure Boot (neither loader is signed), and a serial console for when
    # amdgpu leaves the monitor dark.
    domain = pkgs.writeText "${name}.xml" ''
      <domain type='kvm'>
        <name>${name}</name>
        <!-- Pinned: a re-define without a uuid fails ("already exists with uuid"). -->
        <uuid>${uuid}</uuid>
        <memory unit='GiB'>16</memory>
        <currentMemory unit='GiB'>16</currentMemory>
        <vcpu placement='static'>${toString pt.guestThreads}</vcpu>
        <iothreads>1</iothreads>
      ${pt.cputune}
        <os firmware='efi'>
          <type arch='x86_64' machine='pc-q35-11.1'>hvm</type>
          <firmware>
            <feature enabled='no' name='secure-boot'/>
            <feature enabled='no' name='enrolled-keys'/>
          </firmware>
        </os>
        <features>
          <acpi/>
          <apic/>
          <vmport state='off'/>
        </features>
        <cpu mode='host-passthrough' check='none' migratable='off'>
          <!-- 7 cores x 2 threads. OpenBSD leaves the second thread of each
               core idle unless hw.smt=1 (docs/bsd-vms.md). -->
          <topology sockets='1' dies='1' clusters='1' cores='${toString (builtins.length pt.guestCores)}' threads='2'/>
          <cache mode='passthrough'/>
          <!-- So OVMF's 64-bit PCI window fits the 16 GiB Resizable BAR. -->
          <maxphysaddr mode='passthrough'/>
          <feature policy='require' name='topoext'/>
        </cpu>
        <clock offset='utc'/>
        <on_poweroff>destroy</on_poweroff>
        <on_reboot>restart</on_reboot>
        <on_crash>destroy</on_crash>
        <pm>
          <suspend-to-mem enabled='no'/>
          <suspend-to-disk enabled='no'/>
        </pm>
        <devices>
          <disk type='file' device='disk'>
            <driver name='qemu' type='raw' cache='none' io='io_uring' discard='unmap' iothread='1'/>
            <source file='${disk}'/>
            <target dev='vda' bus='virtio'/>
            <boot order='1'/>
          </disk>
          <!-- The installer. While the disk is empty OVMF falls through to it. -->
          <disk type='file' device='cdrom'>
            <driver name='qemu' type='raw'/>
            <source file='${installIso}' startupPolicy='optional'/>
            <target dev='sdb' bus='sata'/>
            <readonly/>
            <boot order='2'/>
          </disk>
          <interface type='network'>
            <mac address='${mac}'/>
            <source network='default'/>
            <model type='virtio'/>
          </interface>
      ${pt.gpuDevs}
      ${pt.usbDevs}
          <!-- `virsh console ${name}` from the host (over ssh from tempest). -->
          <serial type='pty'>
            <target port='0'/>
          </serial>
          <console type='pty'>
            <target type='serial' port='0'/>
          </console>
          <video>
            <model type='none'/>
          </video>
          <rng model='virtio'>
            <backend model='random'>/dev/urandom</backend>
          </rng>
          <memballoon model='none'/>
        </devices>
      </domain>
    '';
  in {
    virtualisation.libvirtd.hooks.qemu."${name}-gpu" = pt.hook name;

    # Re-defined at boot and on every switch, as win11's. The NVRAM is in
    # /var/lib/libvirt (system/persistence.nix).
    systemd.services."${name}-define" = {
      description = "Define the ${name} libvirt domain";
      after = ["libvirtd.service"];
      requires = ["libvirtd.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [config.virtualisation.libvirtd.package pkgs.coreutils];
      script =
        pt.defineScript domain
        + ''
          [ -e ${disk} ] || truncate -s ${diskSize} ${disk}
          # Fails once the reservation exists, which is the point.
          virsh net-update default add-last ip-dhcp-host \
            "<host mac='${mac}' name='${name}' ip='${ip}'/>" --live --config 2>/dev/null || true
        '';
    };

    services.displayManager.sessionPackages = [(pt.sessionEntry name label)];

    systemd.tmpfiles.rules = ["d ${dir} 0755 root root -"];
  };
in {
  config = lib.mkMerge (map mkVm vms);
}
