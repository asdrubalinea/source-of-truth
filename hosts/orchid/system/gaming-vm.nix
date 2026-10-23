{
  config,
  lib,
  pkgs,
  ...
}: let
  name = "win11";
  dir = "/var/lib/vms/${name}";
  disk = "${dir}/disk.raw";
  # Sparse, so only what Windows writes takes space on rpool.
  diskSize = "1T";
  installIso = "/var/lib/vms/iso/win11.iso";
  unattendIso = "${dir}/unattend.iso";
  passwordFile = "/persist/secrets/${name}/password";

  # The 9070 XT goes to the guest on every start and comes back at shutdown
  # (see the hook below); cores 1-7 leave the host meanwhile. Set to false to
  # run the VM on its emulated VGA alone, with the card never leaving the
  # host. See docs/gaming-vm.md.
  passthrough = true;

  # The 9070 XT and its HDMI audio. Each is alone in its IOMMU group (14 and
  # 15), behind the card's own PCIe switch, so nothing else has to follow it
  # into the guest. The card is also the boot VGA (the iGPU is 10:00.0, with
  # nothing plugged in), so the console and greeter run on it too: while the
  # guest has it, the host has no screen.
  gpu = "0000:03:00.0";

  # 7800X3D: one CCD, so every core shares the V-Cache; cpu N and N+8 are SMT
  # siblings. The guest gets cores 1-7 with both threads; the host keeps core
  # 0 alone — QEMU's emulator thread (and vhost-net) on cpu 0, the disk
  # iothread on its sibling 8. While the VM runs the host has no screen and no
  # input and serves nothing interactive, so one core is all it needs.
  hostCpus = "0,8";
  allCpus = "0-15";
  guestCores = [1 2 3 4 5 6 7];
  guestThreads = 2 * builtins.length guestCores;

  # vCPU 2k and 2k+1 are one guest core's two threads (threads='2' below), so
  # they land on one host core's two siblings.
  vcpupins = lib.concatStringsSep "\n" (lib.genList (i: let
      cpu = builtins.elemAt guestCores (i / 2) + 8 * lib.mod i 2;
    in "    <vcpupin vcpu='${toString i}' cpuset='${toString cpu}'/>")
    guestThreads);

  # Dynamic passthrough: the card belongs to amdgpu (llama-cpp, LACT) until the
  # domain starts. managed='yes' on the hostdevs below makes libvirt itself
  # unbind the card from amdgpu/snd_hda_intel, bind vfio-pci, and reverse that
  # after shutdown. This hook only clears the way: amdgpu does not survive
  # being unbound while something still holds the card open, so anything that
  # does is stopped first, and the start is refused if a stray holder remains.
  # Installed only with `passthrough`.
  #
  # With the card gone the host only idles behind the guest, so for the VM's
  # lifetime it also trades its power saving for the guest's latency: every
  # core's EPP to `performance` (amd_pstate boosts without hesitating) and
  # PCIe ASPM off, so the links to the GPU and the USB controller never nap.
  # The values found at start are put back at release.
  hook = pkgs.writeShellScript "${name}-gpu" ''
    set -euo pipefail
    [ "$1" = ${name} ] || exit 0
    systemctl=${config.systemd.package}/bin/systemctl
    slices="system.slice user.slice init.scope"
    saved=/run/${name}-host-tuning
    aspm=/sys/module/pcie_aspm/parameters/policy
    epp() { for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo "$1" >"$f"; done; }

    case "$2/$3" in
      prepare/begin)
        # llama-cpp is not restarted afterwards; it is on-demand anyway.
        $systemctl stop llama-cpp.service lactd.service
        for n in /dev/dri/by-path/pci-${gpu}-card /dev/dri/by-path/pci-${gpu}-render; do
          if ${pkgs.psmisc}/bin/fuser -s "$n"; then
            echo "${name}: $n is still open, refusing to unbind the GPU:" >&2
            ${pkgs.psmisc}/bin/fuser -v "$n" >&2 || true
            exit 1
          fi
        done
        for s in $slices; do $systemctl set-property --runtime "$s" AllowedCPUs=${hostCpus}; done
        # Saved only once the start is going ahead: a refused start still gets
        # a release, which then finds nothing to restore.
        {
          cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference
          sed 's/.*\[\(.*\)\].*/\1/' $aspm
        } >$saved
        epp performance
        echo performance >$aspm || echo "${name}: could not switch PCIe ASPM off" >&2
        ;;
      release/end)
        for s in $slices; do $systemctl set-property --runtime "$s" AllowedCPUs=${allCpus}; done
        if [ -r $saved ]; then
          { read -r was_epp; read -r was_aspm; } <$saved
          epp "$was_epp"
          echo "$was_aspm" >$aspm || true
          rm -f $saved
        fi
        # By release libvirt has handed the card back to amdgpu; lactd
        # re-applies the undervolt from hardware.nix at start. If the card did
        # not come back (reset failure), lactd starts without it.
        $systemctl start lactd.service || true
        ;;
    esac
  '';

  gpuDevs = lib.optionalString passthrough ''
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source><address domain='0x0000' bus='0x03' slot='0x00' function='0x0'/></source>
    </hostdev>
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source><address domain='0x0000' bus='0x03' slot='0x00' function='0x1'/></source>
    </hostdev>
  '';

  # The chipset's USB controller (0d:00.0), whole, on every start. The
  # keyboard (Keychron Q4), the mouse's receiver (Logitech) and the Bluetooth
  # adapter (TP-Link UB500) are on it, and nothing the host needs is. A PCI
  # hostdev rather than one USB hostdev per device: Windows' own xHCI driver
  # then polls the mouse at its native rate with no QEMU emulation in the
  # path, and whatever is plugged into those ports while the VM runs is the
  # guest's too. The catch is the same in reverse: a device moved to another
  # port (another controller) stays with the host. The IOMMU group (24) only
  # adds the chipset downstream port in front of it (05:0c.0), a bridge that
  # stays with the host; the controller has no FLR and is reset through that
  # port's secondary bus. While Windows is up the host has no keyboard, mouse
  # or Bluetooth: ssh in from tempest if the guest hangs (`virsh destroy
  # win11`).
  usbDevs = ''
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source><address domain='0x0000' bus='0x0d' slot='0x00' function='0x0'/></source>
    </hostdev>
  '';

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
      <cputune>
    ${vcpupins}
        <emulatorpin cpuset='0'/>
        <iothreadpin iothread='1' cpuset='8'/>
      </cputune>
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
    ${usbDevs}
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

  # A "Windows 11" entry in tuigreet's session list (system/session.nix), next
  # to mango and niri. The card is the boot VGA and the desktop runs on it, so
  # the VM can only start with no compositor up; picked from the greeter, that
  # is already true. The session starts the domain and then just waits: the
  # screen goes dark as the card moves, and when Windows shuts down the card
  # comes back, this exits, and greetd puts the greeter back up. Runs as the
  # logged-in user, who reaches qemu:///system through the libvirtd group.
  session = pkgs.writeShellApplication {
    name = "${name}-session";
    runtimeInputs = [config.virtualisation.libvirtd.package pkgs.coreutils];
    text = ''
      vsh() { virsh -c qemu:///system "$@"; }

      if [ "$(vsh domstate ${name} 2>/dev/null)" != running ]; then
        echo "Starting ${name}. The screen goes dark until Windows shuts down."
        # A refused start changes nothing (the hook checks before it unbinds),
        # so it is safe to retry: the compositor just logged out of may not
        # have let go of the card yet.
        tries=0
        until err=$(vsh start ${name} 2>&1); do
          tries=$((tries + 1))
          if [ "$tries" -ge 5 ]; then
            printf '%s\n\n%s\n' "$err" "${name} did not start. Enter goes back to the greeter."
            read -r _ || true
            exit 1
          fi
          sleep 3
        done
      fi

      # "in shutdown" and "paused" are still up; an error (libvirtd
      # restarting) is not an answer, so keep waiting through it.
      while :; do
        case "$(vsh domstate ${name} 2>/dev/null)" in
          "shut off" | crashed) break ;;
        esac
        sleep 5
      done
    '';
  };
  sessionEntry =
    (pkgs.writeTextDir "share/wayland-sessions/${name}.desktop" ''
      [Desktop Entry]
      Name=Windows 11
      Comment=Start the ${name} VM with the 9070 XT; back to the greeter when Windows shuts down
      Exec=${session}/bin/${name}-session
      Type=Application
    '')
    .overrideAttrs {passthru.providedSessions = [name];};
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
    hooks.qemu = lib.mkIf passthrough {"${name}-gpu" = hook;};

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
    script = ''
      virsh define ${domain}
      # The NAT network the guest sits on; RDP reaches it over tailscale
      # inside Windows, or `ssh -L 3389:<guest ip>:3389 orchid`.
      virsh net-autostart default
      virsh net-info default | grep -q '^Active: *yes' || virsh net-start default
    '';
  };

  # DHCP/DNS from libvirt's dnsmasq to the guest. Only our own guest sits on
  # this bridge.
  networking.firewall.trustedInterfaces = ["virbr0"];

  environment.systemPackages = [install];

  # Without passthrough the VM runs fine from inside the desktop, so the
  # greeter entry only exists with it.
  services.displayManager.sessionPackages = lib.optional passthrough sessionEntry;

  systemd.tmpfiles.rules = [
    "d /var/lib/vms/iso 0755 root root -"
    "d /persist/secrets/${name} 0700 root root -"
  ];
}
