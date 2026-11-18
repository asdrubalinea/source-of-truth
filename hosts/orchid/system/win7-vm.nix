{
  config,
  lib,
  pkgs,
  ...
}: let
  pt = import ./passthrough-vm.nix {inherit config lib pkgs;};
  name = "win7";
  dir = "/var/lib/vms/${name}";
  disk = "${dir}/disk.raw";
  # Sparse, so only what Windows writes takes space on rpool.
  diskSize = "256G";
  installIso = "/var/lib/vms/iso/${name}.iso";

  # Windows 7, installed by hand, for the unofficial WDDM 2 backport
  # (w7revived). Setup: docs/win7-vm.md.
  #
  # Unlike win11 and the BSDs, everything is a device Windows 7 has an inbox
  # driver for: SeaBIOS rather than OVMF (7's UEFI boot needs an int10h
  # handler that current OVMF lacks), SATA rather than virtio (virtio-win
  # dropped Windows 7), e1000, and USB 2 (7 has no xHCI driver).
  #
  # Off: emulated VGA over VNC from inside the desktop, with the card never
  # leaving the host. Install Windows, the updates, WDDM2 and the AMD driver
  # like this. On: the VM starts from the greeter like the others and also
  # gets the 9070 XT, as a second display that only lights up once AMD's
  # driver loads. Not as the primary: SeaBIOS running the card's legacy
  # VBIOS (x-vga) left the monitor on stale VRAM, a red/green grid. The
  # emulated VGA stays, reached over VNC from tempest.
  passthrough = true;

  # Not the chipset USB controller that win11 and the BSDs get: it is xHCI,
  # which Windows 7 cannot drive. Single devices instead, onto the emulated
  # USB 2 controller below. The keyboard has to be on its cable: Windows 7
  # has no Bluetooth LE. Absent devices are skipped, not fatal.
  usbDevices = [
    {
      vendor = "0x046d";
      product = "0xc547"; # Logitech receiver (mouse)
    }
    {
      vendor = "0x9d5b";
      product = "0x2561"; # KBDFans Agar Mini, on its cable
    }
  ];

  usbDevs = lib.concatMapStrings (d: ''
      <hostdev mode='subsystem' type='usb' managed='yes'>
        <source startupPolicy='optional'>
          <vendor id='${d.vendor}'/>
          <product id='${d.product}'/>
        </source>
      </hostdev>
    '')
    usbDevices;

  devices =
    (
      if passthrough
      then pt.gpuDevs + usbDevs
      else "<input type='tablet' bus='usb'/>"
    )
    + ''
      <graphics type='vnc' autoport='yes'>
        <listen type='address' address='127.0.0.1'/>
      </graphics>
      <video>
        <model type='vga' primary='yes'/>
      </video>
    '';

  domain = pkgs.writeText "${name}.xml" ''
    <domain type='kvm'>
      <name>${name}</name>
      <!-- Pinned: a re-define without a uuid fails ("already exists with uuid"). -->
      <uuid>7e60457e-128f-4ead-9e61-1a862d31f7b4</uuid>
      <memory unit='GiB'>16</memory>
      <currentMemory unit='GiB'>16</currentMemory>
      <vcpu placement='static'>${toString pt.guestThreads}</vcpu>
      <!-- Unused (SATA cannot take one), but pt.cputune pins iothread 1. -->
      <iothreads>1</iothreads>
    ${pt.cputune}
      <!-- The host board's identity, as on win11: under QEMU's, AMD's driver
           drives none of the 9070 XT's outputs (./gaming-vm.nix). -->
      <sysinfo type='smbios'>
        <system>
          <entry name='manufacturer'>ASRock</entry>
          <entry name='product'>B650 Pro RS</entry>
        </system>
        <baseBoard>
          <entry name='manufacturer'>ASRock</entry>
          <entry name='product'>B650 Pro RS</entry>
        </baseBoard>
      </sysinfo>
      <os>
        <type arch='x86_64' machine='pc-q35-11.1'>hvm</type>
        <smbios mode='sysinfo'/>
      </os>
      <features>
        <acpi/>
        <apic/>
        <!-- Only the enlightenments Windows 7 knows. -->
        <hyperv mode='custom'>
          <relaxed state='on'/>
          <vapic state='on'/>
          <spinlocks state='on' retries='8191'/>
        </hyperv>
        <vmport state='off'/>
      </features>
      <cpu mode='host-passthrough' check='none' migratable='off'>
        <topology sockets='1' dies='1' clusters='1' cores='${toString (builtins.length pt.guestCores)}' threads='2'/>
        <cache mode='passthrough'/>
        <!-- So the 64-bit PCI window fits the 16 GiB Resizable BAR. -->
        <maxphysaddr mode='passthrough'/>
        <feature policy='require' name='topoext'/>
        <feature policy='disable' name='svm'/>
      </cpu>
      <clock offset='localtime'>
        <timer name='rtc' tickpolicy='catchup'/>
        <timer name='pit' tickpolicy='delay'/>
        <timer name='hpet' present='no'/>
      </clock>
      <on_poweroff>destroy</on_poweroff>
      <on_reboot>restart</on_reboot>
      <on_crash>destroy</on_crash>
      <pm>
        <suspend-to-mem enabled='no'/>
        <suspend-to-disk enabled='no'/>
      </pm>
      <devices>
        <disk type='file' device='disk'>
          <driver name='qemu' type='raw' cache='none' io='io_uring' discard='unmap'/>
          <source file='${disk}'/>
          <!-- Seen as an SSD, so Windows sends TRIM (discard='unmap' above). -->
          <target dev='sda' bus='sata' rotation_rate='1'/>
          <boot order='1'/>
        </disk>
        <!-- The installer. While the disk is empty SeaBIOS falls through to it. -->
        <disk type='file' device='cdrom'>
          <driver name='qemu' type='raw'/>
          <source file='${installIso}' startupPolicy='optional'/>
          <target dev='sdb' bus='sata'/>
          <readonly/>
          <boot order='2'/>
        </disk>
        <!-- Updates, Firefox, the WDDM2 package and the AMD driver. -->
        <disk type='file' device='cdrom'>
          <driver name='qemu' type='raw'/>
          <source file='/var/lib/vms/iso/${name}-updates.iso' startupPolicy='optional'/>
          <target dev='sdc' bus='sata'/>
          <readonly/>
        </disk>
        <interface type='network'>
          <mac address='52:54:00:9e:83:07'/>
          <source network='default'/>
          <model type='e1000'/>
        </interface>
        <!-- USB 2 with its USB 1.1 companions: all drivers Windows 7 has. -->
        <controller type='usb' index='0' model='ich9-ehci1'/>
        <controller type='usb' index='0' model='ich9-uhci1'>
          <master startport='0'/>
        </controller>
        <controller type='usb' index='0' model='ich9-uhci2'>
          <master startport='2'/>
        </controller>
        <controller type='usb' index='0' model='ich9-uhci3'>
          <master startport='4'/>
        </controller>
    ${devices}
        <memballoon model='none'/>
      </devices>
    </domain>
  '';
in {
  virtualisation.libvirtd.hooks.qemu = lib.mkIf passthrough {"${name}-gpu" = pt.hook name;};

  # Re-defined at boot and on every switch, as win11's: change it here, not in
  # virt-manager.
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
    script = ''
      virsh define ${domain}
      virsh net-autostart default
      virsh net-info default | grep -q '^Active: *yes' || virsh net-start default
      [ -e ${disk} ] || truncate -s ${diskSize} ${disk}
    '';
  };

  # Without passthrough the VM runs fine from inside the desktop, so the
  # greeter entry only exists with it.
  services.displayManager.sessionPackages = lib.optional passthrough (pt.sessionEntry name "Windows 7");

  systemd.tmpfiles.rules = ["d ${dir} 0755 root root -"];
}
