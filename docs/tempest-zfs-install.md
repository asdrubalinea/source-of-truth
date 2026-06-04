# tempest — ZFS-on-LUKS reinstall runbook

Step-by-step install for the new SSD. The **why** behind every choice lives in
[`adr/0001-zfs-on-luks-tempest.md`](adr/0001-zfs-on-luks-tempest.md); this file
is just the procedure.

End state: btrfs → **ZFS-on-LUKS**, tmpfs-root impermanence, **lanzaboote +
Secure Boot**, **TPM2 silent auto-unlock** (PCR 7), hibernation preserved.

> **Ordering is load-bearing.** Two things will bite if done out of order:
> 1. **lanzaboote can't sign before its keys exist** → first install bootstraps
>    on systemd-boot, then switches to lanzaboote (Phase 4–5).
> 2. **Enabling Secure Boot changes PCR 7** → TPM2 is enrolled **last**, only
>    after Secure Boot is on (Phase 6).

---

## Phase 0 — Before you touch the new SSD

You're installing onto a **new** disk, so the **old SSD is your backup** — keep
it intact and pull what you need off it later (Phase 7). The old disk is
**degrading** (it threw `[Errno 5] I/O error` during a borg run), so don't lean
on it more than necessary.

```sh
# 1. Commit + push the config — the installer builds the flake from GitHub,
#    NOT from the wiped disk. tempest-zfs currently has no upstream.
cd /persist/source-of-truth
git status                       # confirm the ZFS change set is committed
git push -u origin tempest-zfs
```

Confirm the three **irreplaceable** secrets still exist on the old disk (you'll
copy them back in Phase 7 — they are not in git):

- `/persist/secrets/vaultwarden-backup/id_ed25519` — pulls the vault from orchid
- `/persist/borg-home-backup/passphrase` — borg restore access
- `/home/irene/.ssh/id_ed25519` — SSH / git / borg key

---

## Phase 1 — Prep the new SSD (4K LBA)

Boot a **NixOS live USB**. Physically install the new SSD (single M.2 slot →
it becomes `/dev/nvme0n1`; verify with `lsblk`).

```sh
# Reformat the namespace to a 4096-byte LBA for native 4K alignment.
# DESTRUCTIVE — fresh drive only.
sudo nvme id-ns /dev/nvme0n1 | grep lbaf      # find a format with "ms:0 lbads:12" (4096)
sudo nvme format /dev/nvme0n1 --lbaf=<index>  # e.g. --lbaf=1

lsblk -o NAME,LOG-SEC,PHY-SEC /dev/nvme0n1    # expect 4096/4096
```

If the drive advertises **no** 4 K LBA format, skip this — `--sector-size 4096`
on LUKS (already in `disks/tempest.nix`) still gives most of the benefit.

---

## Phase 2 — Get the config + bootstrap bootloader override

```sh
git clone https://github.com/asdrubalinea/source-of-truth
cd source-of-truth
git checkout tempest-zfs
```

**First install only:** lanzaboote can't sign without keys, so install on
systemd-boot first. Apply this temporary override (reverted in Phase 5):

```sh
# 1) Disable Secure Boot module:
#    hosts/tempest/default.nix → comment the import:
#      # ../../modules/secure-boot.nix
#
# 2) Re-enable systemd-boot for the bootstrap:
#    hosts/tempest/system/boot.nix → inside `loader = { ... }` add:
#      systemd-boot.enable = true;
```

(Edit with whatever's on the live USB — `nano`, `vim`. A dirty flake is fine.)

---

## Phase 3 — Partition, format, install

`tempest-install <device>` runs disko (destroy → format → mount) **and**
`nixos-install` in one shot. The target device is a required argument (no
default), so pass the NVMe by-id path explicitly.

```sh
./tempest-install /dev/disk/by-id/nvme-Corsair_MP700_PRO_SE_A8WFB416001JKK
# disko prompts for the LUKS passphrase → set a STRONG one.
# This is your permanent fallback once the TPM is enrolled. Do not lose it.
```

Reboot into the new system. Enter the LUKS passphrase manually (TPM not enrolled
yet). You should land in a working ZFS system on systemd-boot.

```sh
# Verify the foundation:
zpool status                 # rpool ONLINE, no errors
zfs list                     # rpool/{nix,persist,persist/home,sbctl,reserved}
findmnt /persist /persist/home /nix /var/lib/sbctl
swapon --show                # /dev/dm-? (pool-swap), 40G
cat /sys/power/state         # contains "disk" → hibernation available
```

---

## Phase 4 — Generate Secure Boot keys

```sh
sudo sbctl create-keys       # writes the key hierarchy into /var/lib/sbctl
sudo sbctl status
```

These keys now live on the `rpool/sbctl` dataset and persist across reboots.

---

## Phase 5 — Switch to lanzaboote

Revert the Phase 2 override so the committed config (lanzaboote ON) takes over:

```sh
git checkout hosts/tempest/default.nix hosts/tempest/system/boot.nix

sudo nixos-rebuild boot --flake .#tempest   # lanzaboote builds + SIGNS the UKI
sudo sbctl verify                           # ESP files report "signed"
```

Reboot to confirm you boot via lanzaboote (still entering the LUKS passphrase;
Secure Boot is not enabled yet).

---

## Phase 6 — Enable Secure Boot, then enroll the TPM (order matters!)

```sh
# 6a. Put firmware into Setup Mode:
#     Reboot → enter BIOS (F2 on Framework) → Security → Secure Boot →
#     erase/clear existing keys (enters "Setup Mode"). Save & exit, boot back in.

# 6b. Enroll your keys (+ Microsoft's, so fwupd capsule updates / option ROMs survive):
sudo sbctl enroll-keys --microsoft

# 6c. Reboot → enter BIOS → ENABLE Secure Boot. Save & exit.

# 6d. Back in NixOS, confirm:
bootctl status               # "Secure Boot: enabled (user)"
sbctl status                 # Secure Boot: enabled, your keys installed
```

**Only now** — with Secure Boot on and PCR 7 in its final state — enroll the TPM:

```sh
# /dev/nvme0n1p2 is the LUKS partition (p1 = ESP).
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme0n1p2

sudo systemd-cryptenroll /dev/nvme0n1p2   # lists a tpm2 slot alongside password
```

Reboot → unlock should now be **silent**. The passphrase remains as fallback.

---

## Phase 7 — Restore secrets + data from the old SSD

Connect the old SSD via a USB enclosure, unlock + import read-only if needed,
then copy the three secrets back **with correct permissions**:

```sh
# vaultwarden mirror key (vault re-syncs from orchid once this is back)
sudo install -D -m600 -o root -g root \
  <old>/persist/secrets/vaultwarden-backup/id_ed25519 \
  /persist/secrets/vaultwarden-backup/id_ed25519

# borg passphrase — tighten perms (was world-readable on the old system)
sudo install -D -m600 -o irene -g root \
  <old>/persist/borg-home-backup/passphrase \
  /persist/borg-home-backup/passphrase

# SSH key
install -D -m600 -o irene -g users \
  <old>/home/irene/.ssh/id_ed25519 /home/irene/.ssh/id_ed25519
```

Then restore the rest:

- **/home/irene** — from borg (now that the passphrase + key are back) or rsync
  from the old disk. `borg list <repo>` to confirm the archive is intact.
- Hand-pick from the old `/persist`: `Data/`, `quarantine/`,
  `tribunale-scrape/`, `syncthing-config/` (syncthing device identity).
- **Regenerates itself, leave it:** vaultwarden mirror (re-pulls from orchid),
  grafana/prometheus, NetworkManager connections, tailscale (re-auth), SSH host
  keys, machine-id.

---

## Verification checklist

- [ ] `zpool status -x` → "all pools are healthy"
- [ ] `bootctl status` → Secure Boot enabled (user)
- [ ] Reboot is silent (TPM unlock); passphrase still works as fallback
- [ ] `systemctl status sanoid.timer` active; `zfs list -t snapshot` populating
- [ ] `systemctl status smartd` active
- [ ] Hibernate test: `systemctl hibernate`, resume, then `zpool status` clean
- [ ] borg job succeeds: `systemctl start borgbackup-job-home-irene.service`
- [ ] vaultwarden reachable at https://bitwarden.irene.foo after mirror sync

---

## Escape hatches & gotchas

- **Silent unlock breaks after a firmware/Secure-Boot change** (PCR 7 moved):
  boot with the passphrase, then
  `sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2` and re-run Phase 6d.
- **`sbctl verify` shows unsigned files** after a rebuild: re-run
  `sudo nixos-rebuild boot` (lanzaboote re-signs); never `enroll-keys` before
  `verify` is clean.
- **Won't boot after enabling Secure Boot:** disable Secure Boot in BIOS to get
  back in; you'll still have a working lanzaboote system to fix things.
- **Kernel constraint:** stay on `linuxPackages-cachyos-lts-lto-zen4`. ZFS is
  out-of-tree; a `-latest` kernel will fail to evaluate when it outruns OpenZFS.
- **Growing swap later** (after a RAM upgrade — hibernation needs swap ≥ RAM):
  the root LV is at 95%, so there's ~5% free VG. `sudo swapoff -a` →
  `sudo lvextend -L +<N>G /dev/pool/swap` → `sudo mkswap` → update the swap size
  in `disks/tempest.nix`. ZFS can't shrink, so this headroom is the only way.
