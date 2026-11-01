# Windows gaming VM on orchid

A libvirt domain, `win11`, with the RX 9070 XT passed through to it while it
runs (`passthrough = true` in the nix file; `false` runs it on emulated VGA
alone, the card never leaving the host). Config:
`hosts/orchid/system/gaming-vm.nix`, the single source of the domain XML. It is
re-defined on every boot and on every switch that changes it, so anything
edited in virt-manager is lost: change the nix file instead.

| | |
|---|---|
| CPU | 7 cores / 14 threads (host cores 1–7), `host-passthrough`, L3 passed through, no AMD-V (so no VBS) |
| Host keeps | core 0: QEMU's emulator thread on cpu 0, the disk iothread on cpu 8, everything else on both |
| RAM | 32 GiB, pinned for the VM's lifetime (VFIO) |
| Disk | 1 TiB sparse raw file, `/var/lib/vms/win11/disk.raw` on `rpool/vms/win11`, virtio-blk from the first boot |
| GPU | `03:00.0` + `03:00.1`, handed over from amdgpu on start and given back on stop |
| Firmware | OVMF with Secure Boot available (no Microsoft keys enrolled), swtpm TPM 2.0 |
| Network | libvirt `default` NAT (`virbr0`, 192.168.122.0/24) |
| USB | the chipset USB controller `0d:00.0` (Keychron Q4, Logitech receiver, TP-Link Bluetooth): the guest's while it runs |

## How the GPU moves

Everything in this section applies with `passthrough = true`, the current
setting. With it off, there is no hook and no GPU hostdev: starting the VM
touches neither the card nor the host's CPUs, and the guest's only display is
VNC (and RDP).

The card is the boot VGA, so the desktop, the greeter and the text console
all run on it, and the VM cannot start while a compositor is up. **Start it
from the greeter:** log out, choose the **Windows 11** session (next to mango
and niri), and log in. The screen goes dark as the card moves, Windows comes
up on the monitor, and when Windows shuts down the greeter comes back. If the
start is refused, the session shows why and returns to the greeter on Enter.
`--remember-session` then offers Windows 11 first next time, so pick mango or
niri again for the desktop.

The session is `win11-session` (`gaming-vm.nix`). It starts the domain,
retrying a few times in case the compositor you just left still has the card
open, then waits until the domain is shut off. Over ssh from tempest,
`virsh -c qemu+ssh://irene@orchid/system start win11` works the same way, as
long as nobody is logged in to the desktop.

The card is shared with the host, not reserved at boot. While the VM is off,
amdgpu drives it and llama-cpp and LACT work as usual. On `virsh start win11`:

1. The libvirt hook (`/var/lib/libvirt/hooks/qemu.d/win11-gpu`) stops
   `llama-cpp` and `lactd`. It then refuses the start if any other process
   still has the card's DRM nodes open, because unbinding amdgpu under a live
   client can hang the kernel. Then it pins every host slice to CPUs 0 and
   8, and trades the host's power saving for the guest's latency: every
   core's EPP to `performance`, PCIe ASPM off. The previous values are saved
   in `/run/win11-host-tuning` and put back when the guest stops.
2. libvirt (`managed='yes'`) unbinds `03:00.0`/`03:00.1` from
   amdgpu/snd_hda_intel and binds them to vfio-pci.

On guest shutdown libvirt rebinds the card to amdgpu. The hook then restores
the CPU slices and starts `lactd`, which re-applies the undervolt. llama-cpp
stays stopped; start it again by hand if you want it.

The LACT undervolt does not carry into Windows, because the guest driver
resets the card. Tune it in Adrenalin if you want it there too.

## Performance

The host can do nothing else while the guest has the card, so the domain is
tuned for the guest at the host's expense:

- **CPU:** 7 of 8 cores, each vCPU pair pinned to one core's two SMT threads,
  L3 topology passed through. Host processes are confined to core 0 while
  the guest runs.
- **No AMD-V in the guest** (`<feature policy='disable' name='svm'/>`).
  Windows 11 turns on VBS and Memory Integrity by default when it can start
  Hyper-V, and then every game runs nested. Without AMD-V it can't. This also
  rules out WSL2 and Hyper-V inside the guest.
- **AVIC:** with `<avic>` among the Hyper-V enlightenments, Windows skips
  SynIC auto-EOI, so KVM's AVIC stays active and interrupts reach the vCPUs
  without a VM exit.
- **Host power saving off for the VM's lifetime:** EPP `performance`, PCIe
  ASPM off (the hook).
- **Devices:** a whole USB controller, a virtio-blk disk with its own
  iothread on `io_uring`, multi-queue vhost-net, no emulated VGA (with
  passthrough), no memory balloon, and guest memory on 2 MiB transparent huge
  pages (VFIO faults all of it in at start).
- **In Windows:** the High performance power plan (set by the answer file on a
  fresh install).

Left out on purpose (reasons in the nix file): 1 GiB hugepages, moving
kernel threads and IRQs off the guest cores, and `sync=disabled` on the
dataset.

To check from the host while Windows runs: `virsh -c qemu:///system
qemu-agent-command win11 '{"execute":"guest-info"}'` answers when the agent
is up, and in Windows `msinfo32` shows "Virtualization-based security: Not
enabled".

## One-time setup

```sh
# 1. The dataset for the disk (disko only creates it on a fresh install).
sudo zfs create -o recordsize=64K rpool/vms/win11

# 2. A Windows 11 ISO, under exactly this name. Pro or better: Home cannot host RDP.
#    https://www.microsoft.com/software-download/windows11
sudo cp ~/Downloads/Win11_*_x64.iso /var/lib/vms/iso/win11.iso

# 3. Switch (adds the domain, the hook, kvm.ignore_msrs), then reboot once:
#    kvm is loaded at boot, so ignore_msrs only takes effect after a reboot.
apply
```

The virtio-win driver ISO comes from nixpkgs (`pkgs.virtio-win.src`) and is
already attached as the second CD drive. Put the ISO in place before running
`win11-install`: the disk is created by it, not by hand.

## Installing Windows (unattended)

```sh
systemd-ask-password "Windows password:" | sudo install -m 600 /dev/stdin /persist/secrets/win11/password
sudo win11-install            # add --wipe to erase an existing disk.raw and reinstall
```

`win11-install` installs in one pass, straight onto the virtio disk, using
the same domain as daily use:

1. It re-defines the domain from the repo (`systemctl restart win11-define`)
   and creates a fresh 1 TiB sparse `disk.raw`.
2. It builds `unattend.iso`: the answer file with your password filled in,
   plus a `$WinPEDriver$` folder holding the `viostor` (disk) and `NetKVM`
   (network) drivers for Windows 11.
3. It starts the VM with fresh NVRAM and presses Enter through the CD's
   "Press any key" prompt. From there Setup asks nothing.
4. It waits until the QEMU guest agent answers. The agent is installed by the
   guest tools at first logon, the last step of the answer file. Then it
   ejects the installer and the unattend CD, deletes `unattend.iso`, and
   prints the IP once RDP answers.

Why `$WinPEDriver$`: Setup looks for that folder at the root of every drive.
It loads the drivers it finds there, and it also stages them into the
installed image, so the first boot from the virtio disk has its boot driver.
dockur/windows does the same. Earlier versions loaded `viostor` into Setup
some other way, and the installed image bootlooped on
`INACCESSIBLE_BOOT_DEVICE`. The next version worked around that with a SATA
install followed by a move to virtio, which was fragile. If the script times
out, it stops and says where. The console shows what Windows is waiting
on.

What the answer file does, without asking:

- wipes disk 0, the virtio system disk (EFI + MSR + C:)
- installs **Windows 11 Pro** using Microsoft's generic key (not activated:
  activate with your own key or digital licence)
- en-US, US keyboard, GMT Standard Time (matches Atlantic/Canary)
- creates a local admin `irene`. There's no Microsoft account and no network
  requirement in OOBE, and the privacy prompts are skipped
- enables RDP (NLA on, firewall open) and GPU-accelerated RDP sessions
- gets the virtio disk and NIC drivers from `$WinPEDriver$`, then at first
  logon installs `virtio-win-guest-tools` (the remaining drivers + QEMU guest
  agent)
- turns off automatic BitLocker, sleep and hibernation

Still by hand, over RDP: the AMD Adrenalin driver (Windows Update usually
installs a basic one on its own), Tailscale, and Windows activation.

To watch: `virt-manager -c qemu+ssh://irene@orchid/system`. The console is
the emulated VGA over VNC. If a step stops and waits, the answer file didn't
cover it.

Once the card's output works in Windows (AMD driver in), remove the
`<graphics>` and `<video>` elements from the nix file. While they are present,
Windows has a second, 1280×800 virtual monitor that games may pick. With
passthrough off they are the only screen, so keep them then.

## Reaching it

**RDP.** The guest is behind NAT on orchid. Either install Tailscale in Windows
and RDP to its tailnet name (this also works for streaming later), or tunnel:

```sh
virsh -c qemu+ssh://irene@orchid/system domifaddr win11 --source arp
ssh -L 3389:192.168.122.X:3389 orchid      # then RDP to localhost
```

**Keyboard, mouse, Bluetooth.** The Keychron Q4, the Logitech receiver and the
TP-Link UB500 Bluetooth adapter all sit on the chipset's USB controller
(`0d:00.0`), and the whole controller is passed through (`usbDevs` in the nix
file). Windows' own USB driver then talks to them, at the mouse's native
polling rate, and anything plugged into those ports while Windows runs is
Windows' too. The catch: the ports are fixed, not the devices. A keyboard
moved to a port on another controller stays with the host. `lsusb -t` and
`readlink -f /sys/bus/usb/devices/usbN` show which controller a port is on
(`usb1`/`usb2` are `0d:00.0`). **While Windows runs, the host has no keyboard,
mouse or Bluetooth.** If the guest hangs, ssh in from tempest and `virsh
destroy win11`.

Windows installs the UB500's Realtek driver from Windows Update. Bluetooth
devices pair with the adapter, so headphones paired on the host must be paired
again in Windows.

**Monitor.** The monitor is on the 9070 XT, so Windows takes it over with the
card.

**Streaming later.** Sunshine in the guest plus Moonlight on the client. It
needs a display on the card: the monitor, an HDMI dummy plug, or a virtual
display driver.

## Daily use

```sh
# Normally: the "Windows 11" session at the greeter. By hand, with nobody logged in:
virsh -c qemu:///system start win11
virsh -c qemu:///system shutdown win11     # clean ACPI shutdown; card returns to the host
journalctl -u libvirtd -b | grep win11     # hook output if a start was refused
```

A host shutdown shuts the guest down cleanly (`onShutdown = "shutdown"`; the
default, a managed save, is impossible with a VFIO device).

## When it goes wrong

- **Red/green grid on the monitor, Windows otherwise fine:** the AMD driver is
  drawing on its own "AMD vDisplay" (Device Manager → Monitors) and not on the
  card's real outputs. It does that when the VM's SMBIOS reads as QEMU, so
  the domain carries the host board's identity (`<sysinfo>` in the nix file;
  from `/sys/class/dmi/id`). If the board is ever replaced, update those values.
- **Start refused, "is still open":** the hook found a process holding the card.
  It prints that process, so stop it and retry. If it is niri or mango, the
  desktop is running on the card: log out to the greeter first.
- **Card gone from the host after the VM stops** (`lspci -k -s 03:00.0` shows no
  driver, or amdgpu errors in `dmesg`): RDNA reset trouble. A host reboot gets
  it back. If it keeps happening, switch to dedicating the card: add
  `vfio-pci.ids=1002:7550,1002:ab40` to `boot.kernelParams`, put `vfio_pci` in
  `boot.initrd.kernelModules` ahead of `amdgpu`, and drop the hook. The iGPU's
  IDs differ (`164e`/`1640`), so it stays on amdgpu.
- **Code 43 / Code 12 in Device Manager:** usually the 16 GiB Resizable BAR not
  fitting OVMF's 64-bit MMIO window. Try `-fw_cfg opt/ovmf/X-PciMmio64Mb=65536`
  via `<qemu:commandline>`, or turn Resizable BAR off in the BIOS.
- **Host resets under guest load:** suspect the provisional Curve Optimizer in
  `hosts/orchid/hardware.nix` before the VM.
