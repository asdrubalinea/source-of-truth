# Windows 7 VM on orchid

A libvirt domain, `win7`, for trying the unofficial WDDM 2 backport
(w7revived) on a real Windows 7. Config: `hosts/orchid/system/win7-vm.nix`.

With `passthrough = true` it gets the RX 9070 XT like win11 and the BSDs,
and starts from its own greeter entry, "Windows 7". The GPU hook,
CPU pinning and greeter session are shared with them
(`passthrough-vm.nix`, [gaming-vm.md](gaming-vm.md#how-the-gpu-moves)); only
one of them runs at a time. With `false` it runs on emulated VGA over VNC
from inside the desktop.

| | |
|---|---|
| Disk | `/var/lib/vms/win7/disk.raw`, 256 GiB sparse, SATA |
| Installer | `/var/lib/vms/iso/win7.iso` (first CD) |
| Extras | `/var/lib/vms/iso/win7-updates.iso` (second CD): SHA-2 updates, Firefox ESR, WDDM2 package, AMD driver, `4-LEGGIMI-wddm2.txt` |
| Firmware | SeaBIOS (MBR install) |
| Network | e1000 on libvirt's `default` NAT |

## What differs from win11

Every device has a driver already in Windows 7. That means SeaBIOS instead of
OVMF, because Windows 7's UEFI boot needs int10h. It means SATA instead of
virtio, because virtio-win no longer ships Windows 7 drivers. And it means
e1000 for the network and USB 2 (EHCI + UHCI) for USB.

**Display.** The emulated VGA is always the primary display, and the 9070 XT
is a second one. The card stays dark until AMD's driver loads. Making the card
primary did not work. The card's ROM does carry an x86 image, so SeaBIOS can
run its legacy VBIOS (with `x-vga=on`). But it left the monitor showing stale
VRAM, a red and green grid, and Windows never appeared on it.

**Input.** Win11 and the BSDs get the whole chipset USB controller. That
controller is xHCI, and Windows 7 has no driver for it. So win7 gets single
USB devices instead, listed in `usbDevices`: the Logitech mouse receiver, and
the keyboard. The keyboard must be on its cable, because Windows 7 has no
Bluetooth LE. A listed device that is not plugged in is skipped.

**Board identity.** The SMBIOS reports the host board, as on win11. Without
it, AMD's driver does not drive the card's outputs.

## Install

1. With `passthrough = false`, `apply`, then `virsh -c qemu:///system start
   win7` and `virt-manager -c qemu:///system`.
2. Install Windows, then the updates and the WDDM2 package from the second
   CD, following `4-LEGGIMI-wddm2.txt`.
3. Set `passthrough = true`, `apply`, and pick "Windows 7" in the greeter. The
   monitor stays dark: work over VNC from tempest, with `virt-manager -c
   qemu+ssh://irene@orchid/system`. Install the AMD driver from
   `6-driver-amd\B417693`. If the monitor then lights up, make it the main
   display in Windows and turn the emulated one off.
