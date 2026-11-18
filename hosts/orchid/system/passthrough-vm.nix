# What the libvirt guests that take over orchid's screen share: the 9070 XT,
# the chipset USB controller, the CPU split, the libvirt hook that clears the
# way for them and the greeter session that starts one. A plain function, not
# a module: `import ./passthrough-vm.nix {inherit config lib pkgs;}`. Used by
# ./gaming-vm.nix (win11) and ./bsd-vms.nix (openbsd, freebsd). All pass the
# same card and controller, so only one of them runs at a time; the hook
# refuses the second.
{
  config,
  lib,
  pkgs,
}: rec {
  # The 9070 XT and its HDMI audio. Each is alone in its IOMMU group (14 and
  # 15), behind the card's own PCIe switch, so nothing else has to follow it
  # into the guest. The card is also the boot VGA (the iGPU is 10:00.0, with
  # nothing plugged in), so the console and greeter run on it too: while the
  # guest has it, the host has no screen.
  gpu = "0000:03:00.0";
  gpuAudio = "0000:03:00.1";

  # 7800X3D: one CCD, so every core shares the V-Cache; cpu N and N+8 are SMT
  # siblings. The guest gets cores 1-7 with both threads; the host keeps core
  # 0 alone — QEMU's emulator thread (and vhost-net) on cpu 0, the disk
  # iothread on its sibling 8. While the VM runs the host has no screen and no
  # input and serves nothing interactive, so one core is all it needs.
  hostCpus = "0,8";
  allCpus = "0-15";
  guestCores = [1 2 3 4 5 6 7];
  guestThreads = 2 * builtins.length guestCores;

  # vCPU 2k and 2k+1 are one guest core's two threads (threads='2' in the
  # domain's topology), so they land on one host core's two siblings.
  cputune = ''
    <cputune>
    ${lib.concatStringsSep "\n" (lib.genList (i: let
      cpu = builtins.elemAt guestCores (i / 2) + 8 * lib.mod i 2;
    in "    <vcpupin vcpu='${toString i}' cpuset='${toString cpu}'/>")
    guestThreads)}
        <emulatorpin cpuset='0'/>
        <iothreadpin iothread='1' cpuset='8'/>
      </cputune>
  '';

  # Dynamic passthrough: the card belongs to amdgpu (llama-cpp, LACT) until the
  # domain starts. managed='yes' on the hostdevs below makes libvirt itself
  # unbind the card from amdgpu/snd_hda_intel, bind vfio-pci, and reverse that
  # after shutdown. This hook only clears the way: amdgpu does not survive
  # being unbound while something still holds the card open, so anything that
  # does is stopped first, and the start is refused if a stray holder remains,
  # or if another guest already has the card.
  #
  # With the card gone the host only idles behind the guest, so for the VM's
  # lifetime it also trades its power saving for the guest's latency: every
  # core's EPP to `performance` (amd_pstate boosts without hesitating) and
  # PCIe ASPM off, so the links to the GPU and the USB controller never nap.
  # The values found at start are put back at release.
  hook = name:
    pkgs.writeShellScript "${name}-gpu" ''
      set -euo pipefail
      [ "$1" = ${name} ] || exit 0
      systemctl=${config.systemd.package}/bin/systemctl
      slices="system.slice user.slice init.scope"
      saved=/run/${name}-host-tuning
      aspm=/sys/module/pcie_aspm/parameters/policy
      epp() { for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo "$1" >"$f"; done; }

      case "$2/$3" in
        prepare/begin)
          if [ -e /sys/bus/pci/drivers/vfio-pci/${gpu} ]; then
            echo "${name}: the GPU is already passed to another guest" >&2
            exit 1
          fi
          # llama-cpp is not restarted afterwards; it is on-demand anyway.
          $systemctl stop llama-cpp.service lactd.service
          held=(/dev/dri/by-path/pci-${gpu}-card /dev/dri/by-path/pci-${gpu}-render)
          # The HDMI audio's ALSA nodes too: snd_hda_intel's unbind does not
          # fail while one is open, it waits forever (and libvirtd with it).
          for s in /sys/bus/pci/devices/${gpuAudio}/sound/card*/*; do
            if [ -e "$s/dev" ]; then held+=("/dev/snd/''${s##*/}"); fi
          done
          for n in "''${held[@]}"; do
            if ${pkgs.psmisc}/bin/fuser -s "$n"; then
              echo "${name}: $n is still open, refusing to unbind the GPU:" >&2
              ${pkgs.psmisc}/bin/fuser -v "$n" >&2 || true
              exit 1
            fi
          done
          # Saved before anything changes and only once the start is going
          # ahead: a refused start still gets a release, which then finds
          # nothing to restore (and leaves a running guest's CPUs alone).
          {
            cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference
            sed 's/.*\[\(.*\)\].*/\1/' $aspm
          } >$saved
          for s in $slices; do $systemctl set-property --runtime "$s" AllowedCPUs=${hostCpus}; done
          epp performance
          echo performance >$aspm || echo "${name}: could not switch PCIe ASPM off" >&2
          ;;
        release/end)
          if [ -r $saved ]; then
            for s in $slices; do $systemctl set-property --runtime "$s" AllowedCPUs=${allCpus}; done
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

  gpuDevs = ''
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source><address domain='0x0000' bus='0x03' slot='0x00' function='0x0'/></source>
    </hostdev>
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source><address domain='0x0000' bus='0x03' slot='0x00' function='0x1'/></source>
    </hostdev>
  '';

  # The chipset's USB controller (1022:43f7, 0e:00.0 today), whole, on every
  # start. The keyboard (KBDFans Agar Mini), the mouse's receiver (Logitech)
  # and the Bluetooth adapter (TP-Link UB500) are on it, and nothing the host
  # needs is. Its address is looked up by ID when the domain is defined
  # (defineScript below), not written here: the chipset's buses renumber
  # when a card behind it comes or goes, and a stale 0d:00.0 once handed the
  # guest the Ethernet controller instead, leaving Windows with no keyboard
  # or mouse and the host with no network. A PCI
  # hostdev rather than one USB hostdev per device: the guest's own xHCI driver
  # then polls the mouse at its native rate with no QEMU emulation in the
  # path, and whatever is plugged into those ports while the VM runs is the
  # guest's too. The catch is the same in reverse: a device moved to another
  # port (another controller) stays with the host. The IOMMU group (25 today) only
  # adds the chipset downstream port in front of it (05:0c.0), a bridge that
  # stays with the host; the controller has no FLR and is reset through that
  # port's secondary bus. While a guest is up the host has no keyboard, mouse
  # or Bluetooth: ssh in from tempest if the guest hangs (`virsh destroy
  # <name>`).
  usbDevs = ''
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>@USB_ADDRESS@</source>
    </hostdev>
  '';

  # The body of a <name>-define service: fills in the USB controller's address
  # and defines the domain, then makes sure the NAT network it sits on is up.
  defineScript = domain: ''
    usb=
    for d in /sys/bus/pci/devices/*; do
      [ "$(<"$d/vendor"):$(<"$d/device")" = 0x1022:0x43f7 ] && usb=''${d##*/}
    done
    [ -n "$usb" ] || { echo "no chipset USB controller (1022:43f7) found" >&2; exit 1; }
    IFS=':.' read -r pdom pbus pslot pfn <<<"$usb"
    virsh define <(sed "s|@USB_ADDRESS@|<address domain='0x$pdom' bus='0x$pbus' slot='0x$pslot' function='0x$pfn'/>|" ${domain})
    virsh net-autostart default
    virsh net-info default | grep -q '^Active: *yes' || virsh net-start default
  '';

  # An entry in tuigreet's session list (system/session.nix), next to mango
  # and niri. The card is the boot VGA and the desktop runs on it, so the VM
  # can only start with no compositor up; picked from the greeter, that is
  # already true. The session starts the domain and then just waits: the
  # screen goes dark as the card moves, and when the guest shuts down the card
  # comes back, this exits, and greetd puts the greeter back up. Runs as the
  # logged-in user, who reaches qemu:///system through the libvirtd group.
  sessionEntry = name: label: let
    session = pkgs.writeShellApplication {
      name = "${name}-session";
      runtimeInputs = [config.virtualisation.libvirtd.package pkgs.coreutils config.systemd.package];
      text = ''
        vsh() { virsh -c qemu:///system "$@"; }

        # wireplumber keeps the card's HDMI audio open for as long as it runs
        # (lingering, it outlives the desktop), and the hook refuses the start
        # while it does. The host's sound goes out over that HDMI, so it comes
        # back up on the way out.
        systemctl --user stop wireplumber.service
        trap 'systemctl --user start wireplumber.service' EXIT

        if [ "$(vsh domstate ${name} 2>/dev/null)" != running ]; then
          echo "Starting ${name}. The screen goes dark until ${label} shuts down."
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
  in
    (pkgs.writeTextDir "share/wayland-sessions/${name}.desktop" ''
      [Desktop Entry]
      Name=${label}
      Comment=Start the ${name} VM with the 9070 XT; back to the greeter when ${label} shuts down
      Exec=${session}/bin/${name}-session
      Type=Application
    '')
    .overrideAttrs {passthru.providedSessions = [name];};
}
