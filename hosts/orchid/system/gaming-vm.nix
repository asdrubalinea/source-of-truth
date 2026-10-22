{
  config,
  lib,
  pkgs,
  ...
}: let
  name = "win11";
  dir = "/var/lib/vms/${name}";
  disk = "${dir}/disk.raw";
  installIso = "/var/lib/vms/iso/win11.iso";
  unattendIso = "${dir}/unattend.iso";
  probeDisk = "${dir}/viostor-probe.raw";
  passwordFile = "/persist/secrets/${name}/password";

  # The 9070 XT and its HDMI audio. Each is alone in its IOMMU group (15 and
  # 16), behind the card's own PCIe switch, so nothing else has to follow it
  # into the guest. The iGPU (11:00.0, boot_vga=1) keeps the host console.
  gpu = "0000:03:00.0";

  # 7800X3D: one CCD, so every core shares the V-Cache; cpu N and N+8 are SMT
  # siblings. The guest gets cores 1-6 with both threads, the host keeps cores 0
  # and 7 — QEMU's emulator thread on 0, the disk iothread on 7.
  hostCpus = "0,7,8,15";
  allCpus = "0-15";
  guestCores = [1 2 3 4 5 6];

  # vCPU 2k and 2k+1 are one guest core's two threads (cores='6' threads='2'
  # below), so they land on one host core's two siblings.
  vcpupins = lib.concatStringsSep "\n" (lib.genList (i: let
      cpu = builtins.elemAt guestCores (i / 2) + 8 * lib.mod i 2;
    in "    <vcpupin vcpu='${toString i}' cpuset='${toString cpu}'/>")
    (2 * builtins.length guestCores));

  # Dynamic passthrough: the card belongs to amdgpu (llama-cpp, LACT) until the
  # domain starts. managed='yes' on the hostdevs below makes libvirt itself
  # unbind the card from amdgpu/snd_hda_intel, bind vfio-pci, and reverse that
  # after shutdown. This hook only clears the way: amdgpu does not survive
  # being unbound while something still holds the card open, so anything that
  # does is stopped first, and the start is refused if a stray holder remains.
  hook = pkgs.writeShellScript "${name}-gpu" ''
    set -euo pipefail
    [ "$1" = ${name} ] || exit 0
    systemctl=${config.systemd.package}/bin/systemctl
    slices="system.slice user.slice init.scope"

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
        ;;
      release/end)
        for s in $slices; do $systemctl set-property --runtime "$s" AllowedCPUs=${allCpus}; done
        # By release libvirt has handed the card back to amdgpu; lactd
        # re-applies the undervolt from hardware.nix at start. If the card did
        # not come back (reset failure), lactd starts without it.
        $systemctl start lactd.service || true
        ;;
    esac
  '';

  # The domain, in two variants of one template. `installing` is the shape
  # win11-install uses for a fresh install: the system disk on emulated SATA,
  # whose driver (storahci) is in every Windows image, plus a 1 GiB virtio disk
  # for the guest tools' viostor driver to bind to, and no GPU. Loading viostor
  # into Setup instead looked fine and then bootlooped on
  # INACCESSIBLE_BOOT_DEVICE: Setup used the driver but never put it in the
  # installed image. Only once viostor is installed as a boot driver does the
  # system disk move to virtio (the normal variant, defined by win11-define).
  mkDomain = installing: let
    systemDisk =
      if installing
      then ''
        <disk type='file' device='disk'>
          <driver name='qemu' type='raw' cache='none' io='io_uring' discard='unmap'/>
          <source file='${disk}'/>
          <target dev='sda' bus='sata'/>
          <boot order='1'/>
        </disk>
        <disk type='file' device='disk'>
          <driver name='qemu' type='raw'/>
          <source file='${probeDisk}'/>
          <target dev='vda' bus='virtio'/>
        </disk>
      ''
      else ''
        <disk type='file' device='disk'>
          <driver name='qemu' type='raw' cache='none' io='io_uring' discard='unmap' iothread='1'/>
          <source file='${disk}'/>
          <target dev='vda' bus='virtio'/>
          <boot order='1'/>
        </disk>
      '';
    gpuDevs = lib.optionalString (!installing) ''
      <hostdev mode='subsystem' type='pci' managed='yes'>
        <source><address domain='0x0000' bus='0x03' slot='0x00' function='0x0'/></source>
      </hostdev>
      <hostdev mode='subsystem' type='pci' managed='yes'>
        <source><address domain='0x0000' bus='0x03' slot='0x00' function='0x1'/></source>
      </hostdev>
    '';
  in
    pkgs.writeText "${name}${lib.optionalString installing "-install"}.xml" ''
      <domain type='kvm'>
        <name>${name}</name>
        <!-- Pinned: the first define generated these, and a re-define without a
             uuid fails ("already exists with uuid"). Windows also ties
             activation and its network profile to them. -->
        <uuid>09b18a5b-d0e2-4f8d-a52a-b857fc0f4c82</uuid>
        <memory unit='GiB'>24</memory>
        <currentMemory unit='GiB'>24</currentMemory>
        <vcpu placement='static'>12</vcpu>
        <iothreads>1</iothreads>
        <cputune>
      ${vcpupins}
          <emulatorpin cpuset='0,8'/>
          <iothreadpin iothread='1' cpuset='7,15'/>
        </cputune>
        <os firmware='efi'>
          <type arch='x86_64' machine='pc-q35-11.1'>hvm</type>
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
          </hyperv>
          <vmport state='off'/>
          <smm state='on'/>
        </features>
        <cpu mode='host-passthrough' check='none' migratable='off'>
          <topology sockets='1' dies='1' clusters='1' cores='6' threads='2'/>
          <cache mode='passthrough'/>
          <feature policy='require' name='topoext'/>
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
      ${systemDisk}
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
          </interface>
      ${gpuDevs}
          <!-- QEMU guest agent (from virtio-win-guest-tools): win11-install
               asks it whether viostor is a boot driver yet. -->
          <channel type='unix'>
            <target type='virtio' name='org.qemu.guest_agent.0'/>
          </channel>
          <tpm model='tpm-crb'>
            <backend type='emulator' version='2.0'/>
          </tpm>
          <controller type='usb' model='qemu-xhci' ports='15'/>
          <input type='tablet' bus='usb'/>
          <graphics type='vnc' autoport='yes'>
            <listen type='address' address='127.0.0.1'/>
          </graphics>
          <video>
            <model type='vga' primary='yes'/>
          </video>
          <rng model='virtio'>
            <backend model='random'>/dev/urandom</backend>
          </rng>
          <memballoon model='none'/>
        </devices>
      </domain>
    '';
  domain = mkDomain false;
  installDomain = mkDomain true;

  # Checked for well-formedness at build time; Setup's own errors are far
  # less helpful.
  unattend = pkgs.runCommand "autounattend.xml" {nativeBuildInputs = [pkgs.libxml2];} ''
    xmllint --noout ${./gaming-vm-autounattend.xml}
    cp ${./gaming-vm-autounattend.xml} $out
  '';

  # Unattended install, from an empty disk to RDP answering on the virtio
  # disk with the GPU attached. See docs/gaming-vm.md.
  install = pkgs.writeShellApplication {
    name = "${name}-install";
    runtimeInputs = with pkgs; [
      config.virtualisation.libvirtd.package
      config.systemd.package
      xorriso
      coreutils
      gawk
      gnugrep
      jq
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

      rm -f ${disk} ${probeDisk}
      truncate -s 512G ${disk}
      truncate -s 1G ${probeDisk}

      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT
      pw=$(<${passwordFile})
      pw=''${pw//&/'&amp;'}
      pw=''${pw//</'&lt;'}
      pw=''${pw//>/'&gt;'}
      tpl=$(<${unattend})
      printf '%s\n' "''${tpl//@PASSWORD@/"$pw"}" >"$tmp/autounattend.xml"
      (umask 077 && xorriso -as mkisofs -quiet -J -r -V UNATTEND -o ${unattendIso} "$tmp")

      agent() { virsh qemu-agent-command ${name} --timeout 10 "$1" 2>/dev/null; }

      # Runs a command in the guest and prints its stdout.
      guest_run() {
        local pid st
        pid=$(agent "$1" | jq -r .return.pid) || return 1
        for _ in $(seq 30); do
          st=$(agent "{\"execute\":\"guest-exec-status\",\"arguments\":{\"pid\":$pid}}") || return 1
          if [ "$(jq -r .return.exited <<<"$st")" = true ]; then
            jq -r '.return["out-data"] // ""' <<<"$st" | base64 -d | tr -d '\r'
            return 0
          fi
          sleep 1
        done
        return 1
      }

      # 0 = SERVICE_BOOT_START: loaded with the kernel, so it can mount C:.
      viostor_boot_start() {
        guest_run '{"execute":"guest-exec","arguments":{"path":"reg.exe","arg":["query","HKLM\\SYSTEM\\CurrentControlSet\\Services\\viostor","/v","Start"],"capture-output":true}}' |
          grep -Eq 'Start +REG_DWORD +0x0$'
      }

      say "phase 1/2: installing onto SATA (15-30 min, a few reboots)"
      say "console: virt-manager -c qemu+ssh://irene@orchid/system"
      virsh define ${installDomain} >/dev/null
      # Fresh NVRAM drops boot entries left by any earlier attempt.
      virsh start ${name} --reset-nvram

      # The disk is empty, so OVMF falls through to the installer CD, whose
      # loader waits ~5 s for "Press any key" and otherwise gives up. Keep
      # pressing one through firmware start-up; Setup itself asks nothing.
      for _ in $(seq 60); do
        virsh send-key ${name} KEY_ENTER >/dev/null 2>&1 || true
        sleep 0.5
      done

      # The agent answers once first logon has run the guest tools installer;
      # viostor may land a little after it.
      deadline=$((SECONDS + 5400))
      until viostor_boot_start; do
        ((SECONDS < deadline)) || die "no viostor boot driver after 90 min; the VM is left on SATA, look at the console"
        sleep 20
      done
      say "viostor is a boot driver; shutting down to move the disk to virtio"

      virsh shutdown ${name} >/dev/null
      deadline=$((SECONDS + 900))
      until [ "$(virsh domstate ${name})" = "shut off" ]; do
        ((SECONDS < deadline)) || die "guest did not shut down within 15 min"
        sleep 5
      done

      # Back to the real domain, from the same unit that defines it at boot.
      systemctl restart ${name}-define.service
      # Setup cached its own copy in the guest; this one held the password.
      rm -f ${unattendIso} ${probeDisk}

      say "phase 2/2: booting from virtio with the GPU"
      virsh start ${name}
      deadline=$((SECONDS + 900))
      while ((SECONDS < deadline)); do
        ip=$(virsh domifaddr ${name} --source lease 2>/dev/null | awk '/ipv4/ {sub(/\/.*/, "", $4); print $4; exit}')
        if [ -n "$ip" ] && timeout 2 bash -c ">/dev/tcp/$ip/3389" 2>/dev/null; then
          say "done. RDP: $ip, user irene"
          exit 0
        fi
        sleep 10
      done
      die "no RDP within 15 min of the virtio boot; look at the console"
    '';
  };
in {
  # Windows gaming VM with the RX 9070 XT passed through. One-time setup and
  # day-to-day use: docs/gaming-vm.md.
  #
  # Guest memory is not backed by explicit hugepages: THP is `always` on this
  # kernel, and VFIO pins all 24 GiB at start anyway, so a reserved pool would
  # only add a way for the start to fail on fragmentation.
  #
  # The VNC display + emulated VGA exist for the Windows install, before RDP
  # and the AMD driver are up. Reach it from tempest with virt-manager on
  # qemu+ssh://orchid/system. Drop both once the monitor or RDP works, or games
  # may pick the 1280x800 virtual screen.
  #
  # USB passthrough for the monitor setup is not wired yet — nothing is plugged
  # into this box. Plug the keyboard/mouse into one rear port, find its
  # controller (`lsusb -t` for the bus, `readlink /sys/bus/usb/devices/usbN`
  # for the PCI address), check it is alone in its IOMMU group and carries
  # nothing the host needs, then add it as one more managed hostdev.
  virtualisation.libvirtd = {
    hooks.qemu."${name}-gpu" = hook;

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

  systemd.tmpfiles.rules = [
    "d /var/lib/vms/iso 0755 root root -"
    "d /persist/secrets/${name} 0700 root root -"
  ];
}
