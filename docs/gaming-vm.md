# Windows gaming VM on orchid

A libvirt domain, `win11`, with the RX 9070 XT passed through to it. Config:
`hosts/orchid/system/gaming-vm.nix`, the single source of the domain XML. It is
re-defined on every boot and on every switch that changes it, so anything
edited in virt-manager is lost: change the nix file instead.

| | |
|---|---|
| CPU | 6 cores / 12 threads (host cores 1–6), `host-passthrough`, L3 passed through |
| Host keeps | cores 0 and 7 (QEMU emulator thread, disk iothread, everything else) |
| RAM | 24 GiB, pinned for the VM's lifetime (VFIO) |
| Disk | sparse raw file, `/var/lib/vms/win11/disk.raw` on `rpool/vms/win11`, virtio-blk |
| GPU | `03:00.0` + `03:00.1`, handed over from amdgpu on start and given back on stop |
| Firmware | OVMF with Secure Boot available (no Microsoft keys enrolled), swtpm TPM 2.0 |
| Network | libvirt `default` NAT (`virbr0`, 192.168.122.0/24) |

## How the GPU moves

The card is shared with the host, not reserved at boot. While the VM is off,
amdgpu drives it and llama-cpp and LACT work as usual. On `virsh start win11`:

1. The libvirt hook (`/var/lib/libvirt/hooks/qemu.d/win11-gpu`) stops
   `llama-cpp` and `lactd`. It then refuses the start if any other process
   still has the card's DRM nodes open, because unbinding amdgpu under a live
   client can hang the kernel. Last, it pins every host slice to CPUs
   0,7,8,15.
2. libvirt (`managed='yes'`) unbinds `03:00.0`/`03:00.1` from
   amdgpu/snd_hda_intel and binds them to vfio-pci.

On guest shutdown libvirt rebinds the card to amdgpu. The hook then restores
the CPU slices and starts `lactd`, which re-applies the undervolt. llama-cpp
stays stopped; start it again by hand if you want it.

The LACT undervolt does not carry into Windows, because the guest driver
resets the card. Tune it in Adrenalin if you want it there too.

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

`win11-install` runs in two phases:

1. **Install on SATA.** It defines an install variant of the domain: the
   system disk on emulated SATA, a 1 GiB virtio "probe" disk, and no GPU. It
   builds `unattend.iso` (the answer file with your password filled in),
   starts the VM with fresh NVRAM, and presses Enter through the CD's "Press
   any key" prompt. Windows installs with its built-in SATA driver. At first
   logon the guest tools install `viostor`, which binds to the probe disk.
2. **Move to virtio.** It asks the QEMU guest agent until `viostor`'s
   service is boot-start (`Start = 0`). Then it shuts the guest down,
   restores the real domain (`systemctl restart win11-define`), deletes
   `unattend.iso` and the probe disk, and boots with the virtio disk and the
   GPU. It prints the IP once RDP answers.

Why: the first version loaded `viostor` into Setup itself. Setup used it, but
never added it to the installed image, so every boot ended in
`INACCESSIBLE_BOOT_DEVICE`. Now the disk only moves to virtio once the guest
confirms the driver loads at boot. If a phase times out, the script stops and
says where. A phase-1 failure leaves the install variant defined, so the
guest stays bootable on SATA. The next boot or switch puts the real domain
back.

What the answer file does, without asking:

- wipes disk 0, the SATA system disk (EFI + MSR + C:)
- installs **Windows 11 Pro** using Microsoft's generic key (not activated:
  activate with your own key or digital licence)
- en-US, US keyboard, GMT Standard Time (matches Atlantic/Canary)
- creates a local admin `irene`. There's no Microsoft account and no network
  requirement in OOBE, and the privacy prompts are skipped
- enables RDP (NLA on, firewall open) and GPU-accelerated RDP sessions
- installs the virtio NIC driver in specialize, then at first logon
  `virtio-win-guest-tools` (the remaining drivers + QEMU guest agent)
- turns off automatic BitLocker, sleep and hibernation

Still by hand, over RDP: the AMD Adrenalin driver (Windows Update usually
installs a basic one on its own), Tailscale, and Windows activation.

To watch: `virt-manager -c qemu+ssh://irene@orchid/system`. The console is
the emulated VGA over VNC. If a step stops and waits, the answer file didn't
cover it.

Afterwards, remove the `<graphics>` and `<video>` elements from the nix file.
While they are present, Windows has a second, 1280×800 virtual monitor that
games may pick.

## Reaching it

**RDP.** The guest is behind NAT on orchid. Either install Tailscale in Windows
and RDP to its tailnet name (this also works for streaming later), or tunnel:

```sh
virsh -c qemu+ssh://irene@orchid/system domifaddr win11 --source arp
ssh -L 3389:192.168.122.X:3389 orchid      # then RDP to localhost
```

**Monitor.** Plug the monitor into the 9070 XT. A keyboard and mouse need a
USB controller passed through as well, which is not wired yet. Plug them into
one rear port and find which controller it belongs to:

```sh
lsusb -t                                   # the bus the device landed on
readlink -f /sys/bus/usb/devices/usbN      # that bus's PCI address
```

The CPU's USB controllers (`11:00.3`, `11:00.4`, `12:00.0`) each sit alone in
their IOMMU group. Add the right one as another `managed='yes'` PCI hostdev. Check
first that it carries nothing the host needs: `12:00.0` has the board's ASRock
LED controller on it.

**Streaming later.** Sunshine in the guest plus Moonlight on the client. It
needs a display on the card: the monitor, an HDMI dummy plug, or a virtual
display driver.

## Daily use

```sh
virsh -c qemu:///system start win11
virsh -c qemu:///system shutdown win11     # clean ACPI shutdown; card returns to the host
journalctl -u libvirtd -b | grep win11     # hook output if a start was refused
```

A host shutdown shuts the guest down cleanly (`onShutdown = "shutdown"`; the
default, a managed save, is impossible with a VFIO device).

## When it goes wrong

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
