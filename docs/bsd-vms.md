# BSD desktop VMs on orchid

Two libvirt domains, `openbsd` and `freebsd`, that get the RX 9070 XT and the
chipset USB controller (keyboard, mouse receiver) while they run, so the BSD
drives the monitor directly. Config: `hosts/orchid/system/bsd-vms.nix`; the
GPU hook, CPU pinning, USB lookup and greeter entries are shared with win11 in
`hosts/orchid/system/passthrough-vm.nix` and work exactly as described in
[gaming-vm.md](gaming-vm.md#how-the-gpu-moves). Only one of `openbsd`,
`freebsd` and `win11` runs at a time: the hook refuses the second.

| | OpenBSD | FreeBSD |
|---|---|---|
| CPU | 7 cores / 14 threads (host cores 1–7), `host-passthrough` | same |
| RAM | 16 GiB | 16 GiB |
| Disk | `/var/lib/vms/openbsd/disk.raw`, 256 GiB sparse, `sd0` | `/var/lib/vms/freebsd/disk.raw`, 256 GiB sparse, `vtbd0` |
| Installer | `/var/lib/vms/iso/openbsd.iso` | `/var/lib/vms/iso/freebsd.iso` |
| Network | `vio0`, always `192.168.122.10` | `vtnet0`, always `192.168.122.11` |
| Greeter entry | OpenBSD | FreeBSD |

Common to both: OVMF without Secure Boot, the libvirt `default` NAT with the
host at `192.168.122.1`, the 9070 XT's HDMI audio passed along with it, and a
serial console (`virsh console <name>`) as a fallback when the monitor stays
dark. The disks are created empty by `<name>-define` at the first switch.

## Setup

Put the installer ISO in place under exactly the name in the table, then
`apply`. Then log out, pick the entry in the greeter, log in. The disk is
empty, so OVMF boots the CD; the installer comes up on the monitor (EFI
framebuffer) and the keyboard is already the guest's.

The installer ISO can stay where it is afterwards: the disk boots first.
Delete it when you no longer need it.

**Filesystem:** the guest's disk is a file on the host's ZFS-on-LUKS pool,
so pick the plain filesystem (FFS on OpenBSD, UFS on FreeBSD), not ZFS, and
no disk encryption. Snapshot from the host instead, with the VM off:
`sudo zfs snapshot rpool/vms@before-upgrade`.

## OpenBSD

```sh
# Check it against SHA256.sig with signify (nix shell nixpkgs#signify) and
# the release's openbsd-80-base.pub.
curl -LO https://cdn.openbsd.org/pub/OpenBSD/8.0/amd64/install80.iso
sudo cp install80.iso /var/lib/vms/iso/openbsd.iso
```

Installer: disk `sd0`, whole disk GPT, auto layout; network `vio0` with
DHCP; all sets from the CD; yes to xenodm for a graphical login.

At first boot `fw_update` fetches the amdgpu firmware. Reboot once more,
then the go/no-go check:

```sh
dmesg | grep -E 'amdgpu|drm'
```

`drm0 at amdgpu0` means accelerated X on the card. If amdgpu does not attach,
X still runs on the EFI framebuffer (`wsfb`): usable, unaccelerated.

Then, as root:

```sh
echo hw.smt=1 >>/etc/sysctl.conf      # use both threads of each core (OpenBSD's default is one)
pkg_add tailscale && rcctl enable tailscaled && rcctl start tailscaled && tailscale up
# A login prompt on the serial line:
sed -i 's|^tty00.*|tty00 "/usr/libexec/getty std.9600" vt220 on secure|' /etc/ttys
```

## FreeBSD

```sh
# The latest RELEASE's disc1 image; check it against CHECKSUM.SHA256 from the
# same directory (signed in the release announcement).
# https://download.freebsd.org/releases/amd64/amd64/ISO-IMAGES/
sudo cp FreeBSD-*-RELEASE-amd64-disc1.iso /var/lib/vms/iso/freebsd.iso
```

Installer (bsdinstall): partitioning **Auto (UFS)**, GPT, on `vtbd0`;
network `vtnet0` with DHCP; enable `sshd`; add `irene` to the `wheel` and
`video` groups.

After the first boot, as root, the graphics driver and its firmware:

```sh
pkg install drm-kmod          # picks the drm-kmod version that matches the release
fwget                         # installs the firmware for the GPU it finds
sysrc kld_list+=amdgpu
reboot
```

Then the go/no-go check:

```sh
dmesg | grep -E 'amdgpu|drm'
```

`[drm] Initialized amdgpu` means the card is driven. If it does not load,
Xorg's `scfb` driver still runs on the EFI framebuffer, unaccelerated. Then
a desktop (`pkg install xorg` plus a window manager, or `sway`) and:

```sh
pkg install tailscale && sysrc tailscaled_enable=YES && service tailscaled start && tailscale up
# A login prompt on the serial line: in /etc/ttys, change ttyu0's
# "onifconsole" to "on".
```

## Use

- **Start:** the greeter entry, as for Windows 11.
- **Stop:** `shutdown -p now` in the guest, or `virsh shutdown <name>` on the
  host (ACPI power button; both BSDs power off on it by default). On
  OpenBSD a plain `halt` without `-p` leaves the VM up and the screen black.
  The greeter returns when the domain is off.
- **ssh:** from the host to the guest's address in the table; from the guest
  to the host at `192.168.122.1`; from anywhere else, over tailscale.
- **Hung guest:** from tempest, `ssh orchid` then `virsh -c qemu:///system
  console <name>` (Ctrl+] to leave) or `virsh -c qemu:///system destroy
  <name>`.

## Known limits

- The open question for both is the 9070 XT (RDNA4): each BSD ports its
  amdgpu driver from Linux, some versions behind, and inside a VM. Nothing on
  the host can fix it if the driver does not attach.
- The TP-Link Bluetooth adapter goes to the guest with the controller.
  OpenBSD has no Bluetooth stack; on FreeBSD it may or may not work.
- No shared folders with the host (no virtiofs or 9p client): scp, git.
- VRR and HDR: not expected.
- Install is by hand, not unattended like win11's.
