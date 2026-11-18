{
  config,
  lib,
  pkgs,
  ...
}: let
  pt = import ./passthrough-vm.nix {inherit config lib pkgs;};
  inherit (pt) guestCores guestThreads;
  name = "win11";
  dir = "/var/lib/vms/${name}";
  disk = "${dir}/disk.raw";
  # Sparse, so only what Windows writes takes space on rpool.
  diskSize = "1T";
  installIso = "/var/lib/vms/iso/win11.iso";
  unattendIso = "${dir}/unattend.iso";
  passwordFile = "/persist/secrets/${name}/password";

  # The 9070 XT goes to the guest on every start and comes back at shutdown
  # (see the hook in ./passthrough-vm.nix); cores 1-7 leave the host
  # meanwhile. Set to false to run the VM on its emulated VGA alone, with the
  # card never leaving the host. See docs/gaming-vm.md.
  passthrough = true;

  gpuDevs = lib.optionalString passthrough pt.gpuDevs;

  # Emulated VGA over VNC: the only screen without passthrough, and only in
  # the way with it, where Windows counts it as a second, 1280x800 monitor
  # that games may pick. With passthrough, OVMF and Windows draw on the 9070
  # XT alone, and the install's console is the monitor.
  console =
    if passthrough
    then ''
      <video>
        <model type='none'/>
      </video>
    ''
    else ''
      <input type='tablet' bus='usb'/>
      <graphics type='vnc' autoport='yes'>
        <listen type='address' address='127.0.0.1'/>
      </graphics>
      <video>
        <model type='vga' primary='yes'/>
      </video>
    '';

  # One domain for the install and for daily use. The system disk is virtio
  # from the first boot: Setup gets viostor from the unattend CD (peDrivers
  # below), so there is no SATA stage to migrate off.
  domain = pkgs.writeText "${name}.xml" ''
    <domain type='kvm'>
      <name>${name}</name>
      <!-- Pinned: the first define generated these, and a re-define without a
           uuid fails ("already exists with uuid"). Windows also ties
           activation and its network profile to them. -->
      <uuid>09b18a5b-d0e2-4f8d-a52a-b857fc0f4c82</uuid>
      <memory unit='GiB'>32</memory>
      <currentMemory unit='GiB'>32</currentMemory>
      <vcpu placement='static'>${toString guestThreads}</vcpu>
      <iothreads>1</iothreads>
    ${pt.cputune}
      <!-- The host board's identity instead of QEMU's ("QEMU", "Standard PC
           (Q35 + ICH9)"). Under the stock values AMD's Windows driver loads
           cleanly but drives none of the 9070 XT's outputs: it paints the
           desktop on an "AMD vDisplay" of its own, and the real monitor shows
           a red/green grid of stale VRAM. The fix reported for exactly that
           (level1techs, "VFIO Passthrough NOT working on 9070 XT (green
           artefacts)"). Values from /sys/class/dmi/id on orchid. -->
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
      <os firmware='efi'>
        <type arch='x86_64' machine='pc-q35-11.1'>hvm</type>
        <smbios mode='sysinfo'/>
        <firmware>
          <feature enabled='yes' name='secure-boot'/>
          <feature enabled='no' name='enrolled-keys'/>
        </firmware>
      </os>
      <features>
        <acpi/>
        <apic/>
        <hyperv mode='custom'>
          <relaxed state='on'/>
          <vapic state='on'/>
          <spinlocks state='on' retries='8191'/>
          <vpindex state='on'/>
          <runtime state='on'/>
          <synic state='on'/>
          <stimer state='on'/>
          <reset state='on'/>
          <frequencies state='on'/>
          <tlbflush state='on'/>
          <ipi state='on'/>
          <!-- Tells Windows not to use SynIC auto-EOI, which would otherwise
               inhibit KVM's AVIC (kvm_amd avic=Y): interrupts then reach the
               vCPUs without a VM exit. The PIT's tickpolicy='delay' below is
               the other AVIC precondition. -->
          <avic state='on'/>
        </hyperv>
        <vmport state='off'/>
        <smm state='on'/>
      </features>
      <cpu mode='host-passthrough' check='none' migratable='off'>
        <topology sockets='1' dies='1' clusters='1' cores='${toString (builtins.length guestCores)}' threads='2'/>
        <cache mode='passthrough'/>
        <!-- The host's 48 address bits, so OVMF sizes its 64-bit PCI window
             from them and the 16 GiB Resizable BAR always fits. -->
        <maxphysaddr mode='passthrough'/>
        <feature policy='require' name='topoext'/>
        <!-- No AMD-V in the guest (orchid has kvm_amd nested=1 for other
             guests). Without it Windows cannot start its own hypervisor, so
             VBS and Memory Integrity, on by default in Windows 11, stay off:
             otherwise every game would run nested under Hyper-V. Also keeps
             AVIC uninhibited. Costs WSL2 and Hyper-V inside the guest. -->
        <feature policy='disable' name='svm'/>
      </cpu>
      <clock offset='localtime'>
        <timer name='rtc' tickpolicy='catchup'/>
        <timer name='pit' tickpolicy='delay'/>
        <timer name='hpet' present='no'/>
        <timer name='hypervclock' present='yes'/>
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
          <driver name='qemu' type='raw' cache='none' io='io_uring' discard='unmap' iothread='1'/>
          <source file='${disk}'/>
          <target dev='vda' bus='virtio'/>
          <boot order='1'/>
        </disk>
        <!-- The Windows installer. While the disk is empty OVMF falls
             through to it; win11-install ejects it once Windows is up. -->
        <disk type='file' device='cdrom'>
          <driver name='qemu' type='raw'/>
          <source file='${installIso}' startupPolicy='optional'/>
          <target dev='sdb' bus='sata'/>
          <readonly/>
          <boot order='2'/>
        </disk>
        <disk type='file' device='cdrom'>
          <driver name='qemu' type='raw'/>
          <source file='${pkgs.virtio-win.src}'>
            <seclabel model='dac' relabel='no'/>
          </source>
          <target dev='sdc' bus='sata'/>
          <readonly/>
        </disk>
        <disk type='file' device='cdrom'>
          <driver name='qemu' type='raw'/>
          <source file='${unattendIso}' startupPolicy='optional'/>
          <target dev='sdd' bus='sata'/>
          <readonly/>
        </disk>
        <interface type='network'>
          <mac address='52:54:00:9e:83:42'/>
          <source network='default'/>
          <model type='virtio'/>
          <!-- Multi-queue vhost-net: NetKVM spreads traffic over the vCPUs
               (RSS) instead of funnelling it through one. -->
          <driver name='vhost' queues='4'/>
        </interface>
    ${gpuDevs}
    ${pt.usbDevs}
        <!-- QEMU guest agent (from virtio-win-guest-tools): its first answer
             tells win11-install that first logon has run. -->
        <channel type='unix'>
          <target type='virtio' name='org.qemu.guest_agent.0'/>
        </channel>
        <tpm model='tpm-crb'>
          <backend type='emulator' version='2.0'/>
        </tpm>
        <controller type='usb' model='qemu-xhci' ports='15'/>
    ${console}
        <rng model='virtio'>
          <backend model='random'>/dev/urandom</backend>
        </rng>
        <memballoon model='none'/>
      </devices>
    </domain>
  '';

  # Checked for well-formedness at build time; Setup's own errors are far
  # less helpful.
  unattend = pkgs.runCommand "autounattend.xml" {nativeBuildInputs = [pkgs.libxml2];} ''
    xmllint --noout ${./gaming-vm-autounattend.xml}
    cp ${./gaming-vm-autounattend.xml} $out
  '';

  # The drivers Setup needs before Windows exists: viostor to see the virtio
  # disk, NetKVM so OOBE has a network. win11-install puts them on the
  # unattend CD as $WinPEDriver$, the folder Setup looks for at the root of
  # every drive. Setup loads what it finds there, and also stages it into the
  # installed image, so the first boot from the virtio disk has its boot
  # driver. (dockur/windows uses the same folder for the same job.) Loading
  # viostor into Setup some other way, in an earlier version of this file,
  # let Setup see the disk but left the driver out of the installed image,
  # which then bootlooped on INACCESSIBLE_BOOT_DEVICE.
  #
  # Copied out of the unpacked package rather than extracted from the ISO
  # directly: the ISO stores identical files once, as hard links into other
  # folders (w11 into 2k25, for NetKVM), so a two-folder extract comes out
  # empty. Only these copies reach the closure.
  peDrivers = pkgs.runCommand "${name}-pe-drivers" {} ''
    mkdir $out
    cp -r ${pkgs.virtio-win}/viostor/w11/amd64 $out/viostor
    cp -r ${pkgs.virtio-win}/NetKVM/w11/amd64 $out/NetKVM
  '';

  # Unattended install, from an empty disk to RDP answering. See
  # docs/gaming-vm.md.
  install = pkgs.writeShellApplication {
    name = "${name}-install";
    runtimeInputs = with pkgs; [
      config.virtualisation.libvirtd.package
      config.systemd.package
      xorriso
      coreutils
      gawk
    ];
    text = ''
      die() { echo "${name}-install: $*" >&2; exit 1; }
      say() { echo "${name}-install: $*"; }

      wipe=0
      case "''${1-}" in
        --wipe) wipe=1 ;;
        "") ;;
        *) die "usage: ${name}-install [--wipe]" ;;
      esac

      [ "$(id -u)" = 0 ] || die "run as root (sudo ${name}-install)"
      [ -f ${installIso} ] || die "no Windows ISO at ${installIso}"
      [ -s ${passwordFile} ] || die "put the Windows account password in ${passwordFile} (root, 0600)"

      # A sparse file reads as a few KiB until something writes to it.
      if [ -e ${disk} ] && [ "$(du -k ${disk} | cut -f1)" -gt 1024 ]; then
        [ "$wipe" = 1 ] || die "${disk} already holds data; rerun with --wipe to erase it and reinstall"
      fi
      if [ "$(virsh domstate ${name})" != "shut off" ]; then
        [ "$wipe" = 1 ] || die "${name} is running; shut it down first (or --wipe, which also powers it off)"
        virsh destroy ${name}
      fi

      # The domain exactly as this file defines it, whatever an earlier
      # version (or virt-manager) left behind.
      systemctl restart ${name}-define.service

      rm -f ${disk}
      truncate -s ${diskSize} ${disk}

      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT
      pw=$(<${passwordFile})
      pw=''${pw//&/'&amp;'}
      pw=''${pw//</'&lt;'}
      pw=''${pw//>/'&gt;'}
      tpl=$(<${unattend})
      printf '%s\n' "''${tpl//@PASSWORD@/"$pw"}" >"$tmp/autounattend.xml"
      cp -r --no-preserve=mode ${peDrivers} "$tmp/\$WinPEDriver\$"
      (umask 077 && xorriso -as mkisofs -quiet -J -r -V UNATTEND -o ${unattendIso} "$tmp")

      say "installing onto the virtio disk (15-30 min, a few reboots)"
      say "console: ${
        if passthrough
        then "the monitor on the 9070 XT"
        else "virt-manager -c qemu+ssh://irene@orchid/system"
      }"
      # Fresh NVRAM drops boot entries left by any earlier attempt.
      virsh start ${name} --reset-nvram

      # The disk is empty, so OVMF falls through to the installer CD, whose
      # loader waits ~5 s for "Press any key" and otherwise gives up. Keep
      # pressing one through firmware start-up; Setup itself asks nothing.
      for _ in $(seq 60); do
        virsh send-key ${name} KEY_ENTER >/dev/null 2>&1 || true
        sleep 0.5
      done

      # The agent answers once first logon has run the guest tools installer,
      # which is the answer file's last step that needs a CD.
      deadline=$((SECONDS + 5400))
      until virsh qemu-agent-command ${name} --timeout 5 '{"execute":"guest-ping"}' >/dev/null 2>&1; do
        ((SECONDS < deadline)) || die "no guest agent after 90 min; look at the console"
        sleep 20
      done

      # Setup cached its own copy of the answer file; this one held the
      # password. Without the installer, a disk that ever fails to boot drops
      # to the firmware rather than into a reinstall prompt.
      virsh change-media ${name} sdb --eject --live >/dev/null
      virsh change-media ${name} sdd --eject --live >/dev/null
      rm -f ${unattendIso}

      deadline=$((SECONDS + 900))
      while ((SECONDS < deadline)); do
        ip=$(virsh domifaddr ${name} --source lease 2>/dev/null | awk '/ipv4/ {sub(/\/.*/, "", $4); print $4; exit}')
        if [ -n "$ip" ] && timeout 2 bash -c ">/dev/tcp/$ip/3389" 2>/dev/null; then
          say "done. RDP: $ip, user irene"
          say "the installer ISO stays at ${installIso}; delete it if you don't plan to reinstall"
          exit 0
        fi
        sleep 10
      done
      die "Windows is up (the guest agent answers) but RDP did not within 15 min; look at the console"
    '';
  };
in {
  # Windows gaming VM, with the RX 9070 XT passed through when `passthrough`
  # is on. One-time setup and day-to-day use: docs/gaming-vm.md.
  #
  # Tuned for the guest at the host's expense, since with passthrough the host
  # can do nothing else meanwhile; docs/gaming-vm.md has the list. Left out on
  # purpose:
  # - 1 GiB hugepages. THP is `always` here and VFIO faults all 32 GiB in at
  #   start, so the guest is on 2 MiB pages already; a 1 GiB pool would have
  #   to be reserved at boot (32 GiB the desktop never gets back) or carved
  #   out at start (fails once memory is fragmented), for a gain of a percent
  #   or two at most.
  # - Moving kernel threads, workqueues and IRQs off the guest cores. The
  #   disk path (ZFS taskqs, dm-crypt's kcryptd) would then decrypt and
  #   decompress every game asset on cpus 0 and 8 alone, and the GPU's
  #   interrupts are better left where AVIC can deliver them.
  # - sync=disabled on the dataset: faster writes, but a host crash could
  #   leave NTFS inconsistent.
  # 32 GiB guest + 16 GiB ARC cap leaves the host 16 GiB.
  #
  # The VNC display + emulated VGA exist only with passthrough off (`console`
  # above). Reach them from tempest with virt-manager on
  # qemu+ssh://orchid/system.
  virtualisation.libvirtd = {
    hooks.qemu = lib.mkIf passthrough {"${name}-gpu" = pt.hook name;};

    # The default, "suspend", is a managed save, which a domain with a VFIO
    # device can't do; host shutdown would then kill Windows mid-write.
    onShutdown = "shutdown";
  };

  # Windows, and some games and monitoring tools, read MSRs that KVM doesn't
  # implement; without this the guest gets a #GP (often a bluescreen) instead
  # of a zero. kvm is loaded at boot, so this takes effect after a reboot.
  boot.extraModprobeConfig = ''
    options kvm ignore_msrs=1 report_ignored_msrs=0
  '';

  # The domain lives in the repo: (re)defined at boot and on every switch that
  # changes it, so edits made in virt-manager are overwritten — change them
  # here. NVRAM and swtpm state are in /var/lib/libvirt (system/persistence.nix);
  # the TPM state matters because Windows 11 may turn on device encryption.
  systemd.services."${name}-define" = {
    description = "Define the ${name} libvirt domain";
    after = ["libvirtd.service"];
    requires = ["libvirtd.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [config.virtualisation.libvirtd.package];
    # The NAT network the guest sits on; RDP reaches it over tailscale inside
    # Windows, or `ssh -L 3389:<guest ip>:3389 orchid`.
    script = pt.defineScript domain;
  };

  # DHCP/DNS from libvirt's dnsmasq to the guest. Only our own guest sits on
  # this bridge.
  networking.firewall.trustedInterfaces = ["virbr0"];

  environment.systemPackages = [install];

  # Without passthrough the VM runs fine from inside the desktop, so the
  # greeter entry only exists with it.
  services.displayManager.sessionPackages = lib.optional passthrough (pt.sessionEntry name "Windows 11");

  systemd.tmpfiles.rules = [
    "d /var/lib/vms/iso 0755 root root -"
    "d /persist/secrets/${name} 0700 root root -"
  ];
}
