# orchid — ZFS-on-LUKS reinstall runbook

New tower: Ryzen 7 7800X3D, 64 GiB, no discrete GPU, no dedicated NIC. End
state: **ZFS-on-LUKS** on a single NVMe, **tmpfs root + impermanence**,
systemd-boot (no Secure Boot), CachyOS LTS `zen4` kernel, **headless** — no rice,
no compositor, no greeter.

Same shape as tempest, minus lanzaboote and ucodenix. The reasoning behind the
layout is [`adr/0001-zfs-on-luks-tempest.md`](adr/0001-zfs-on-luks-tempest.md);
this file is just the procedure. Layout: [`../disks/orchid.nix`](../disks/orchid.nix).

---

## Phase 0 — Before you wipe anything

**orchid is the primary Vaultwarden.** tempest and hydra only run read-only
mirrors of it (`services/vaultwarden-mirror.nix`), and the reinstall destroys
`/persist`. Copy the old pool's `/persist` off-box first — at minimum:

| Path | Why |
| --- | --- |
| `/var/lib/bitwarden_rs` (**not** `/var/lib/vaultwarden`) | the live vault. stateVersion was 23.05, so the old data dir is the `bitwarden_rs` one |
| `/persist/vaultwarden`, `/persist/vaultwarden-export` | vault backups + the snapshot the mirrors pull |
| `/persist/Vault` | the borg `vault` job's source |
| `/persist/gitea` | gitea repos and DB |
| `/persist/syncthing-config` | syncthing device identity — losing it means re-pairing every peer |
| `/persist/diapee-bot`, `/persist/auxologico-check` | service state + `env` files |
| `/persist/borg-*-backup/passphrase`, `/persist/caddy/env`, `/persist/secrets/` | credentials that are deliberately not in the repo |
| `/home/irene/.ssh/` | the key every borg job and the vault mirrors authenticate with |

The vault also exists on tempest and hydra as a mirror, so it is recoverable
either way — but the mirrors are read-only snapshots, not a restore path you want
to discover under pressure.

---

## Phase 0.5 — Rehearse it in a VM (optional, free)

`orchid-vm` is this exact config on a throwaway virtual disk formatted from
`disks/orchid.nix` — same LUKS/LVM/ZFS layout, same impermanence, no hardware
involved. Worth one run before touching the real disk:

```sh
./build-vm orchid
./result/bin/disko-vm      # serial console in this terminal; Ctrl-a x quits
```

The initrd asks for the LUKS passphrase: it is **disko** (disko's
non-interactive default for test images). ~20s after boot the VM prints
`systemctl --failed` plus each failed unit's journal to the console — there is no
way to log in, since root's hash comes from the git-crypt'd `passwords` file.

---

## Phase 1 — Installer

Boot a NixOS installer, get networking up (`nmtui`, or plug in ethernet), then:

```sh
sudo -i
nix-shell -p git --run 'git clone https://github.com/asdrubalinea/source-of-truth /tmp/sot'
cd /tmp/sot
```

Find the target disk. **Always use the by-id path** (model+serial) — `/dev/sdX`
and `/dev/nvme0n1` re-enumerate:

```sh
ls -l /dev/disk/by-id/
```

Optional but do it now if the drive is fresh — reformat it to 4K LBA so
`ashift=12` and LUKS `--sector-size 4096` align natively:

```sh
nvme id-ns /dev/nvme0n1 | grep lbaf       # find a 4096-byte format
nvme format /dev/nvme0n1 --lbaf=<index>   # DESTRUCTIVE
```

---

## Phase 2 — Format and install

Both scripts require host **and** device; a bare run refuses (`disks/orchid.nix`
has only a non-existent placeholder device).

```sh
./disk-format orchid  /dev/disk/by-id/<target>   # destroy,format,mount — DESTRUCTIVE
./disk-install orchid /dev/disk/by-id/<target>   # disko-install .#orchid
```

`disk-format orchid` prompts twice for the LUKS passphrase. `disk-install orchid` exports
`rpool` when it finishes — do **not** reboot if it warns that the export failed,
or the first boot drops to an initrd emergency shell
(`boot.zfs.forceImportRoot = false`, `modules/zfs-on-luks.nix`).

The layout needs a drive of **≥ ~320G**: `root` takes 95% of the VG before the
16G `swap` LV is carved, so a small drive fails the format with "insufficient
free space".

---

## Phase 3 — First boot

Type the LUKS passphrase at the console. Then, because this box is headless,
enrol the TPM so it never asks again:

```sh
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 \
  /dev/disk/by-partlabel/disk-main-luks
sudo reboot
```

PCR 7 covers Secure Boot state. This host does not enable Secure Boot, so
nothing later changes that measurement — unlike tempest, where TPM enrolment has
to come *after* lanzaboote.

> Remote unlock over SSH in the initrd (`boot.initrd.network.ssh`) is **not**
> configured. It is the right answer if this box ever moves somewhere without a
> keyboard; it needs a NIC the initrd can drive and its own host key.

---

## Phase 4 — Restore and finish

The root FS is tmpfs: everything below either lands on a ZFS dataset or is
bind-mounted from `/persist` (`hosts/orchid/system/persistence.nix`).

```sh
# 1. put Phase 0's data back
#    NOTE the vaultwarden target changed: stateVersion is now 25.11, so the live
#    store is /var/lib/vaultwarden (bind-mounted from /persist/var/lib/vaultwarden),
#    NOT /var/lib/bitwarden_rs. Restore into the former.
sudo systemctl stop vaultwarden
sudo rsync -a <backup>/bitwarden_rs/ /var/lib/vaultwarden/
sudo chown -R vaultwarden:vaultwarden /var/lib/vaultwarden
sudo systemctl start vaultwarden

# 2. home + secrets
#    /home/irene is irene:users 0700, enforced by impermanence
rsync -a <backup>/home-irene/ /home/irene/

# 3. home-manager (standalone on this host)
nix run /persist/source-of-truth#home-manager -- switch --flake '.#irene@orchid' -b backup

# 4. tailscale
sudo tailscale up --advertise-exit-node
```

Then check: `zpool status`, `systemctl --failed`, `sitrep`, and that the mirrors
on tempest/hydra can still pull (`systemctl start vaultwarden-mirror-refresh`
there — it authenticates as `vwbackup@orchid`, so orchid's new **host key** has
to be accepted; the mirrors use `StrictHostKeyChecking=accept-new`, and their
stored key for orchid is now stale. Remove orchid's line from
`/var/lib/vaultwarden-mirror/ssh/known_hosts` on each mirror).

Daily driving is `apply` (= `nh os switch && nh home switch -b backup`).

---

## Known follow-ups

- **No NIC config.** `networking.useDHCP` is left at its default, so whatever
  interface appears comes up on DHCP. The old `defaultGateway = 10.0.0.1` and
  the static `enp4s0f0` block are gone.
- **No `hardware.graphics`** and no fonts — add them with the rice when a WM
  comes back (`rices/estradiol` is still in the tree, imported by nothing).
- **Secure Boot** is not set up. Adding it means `sbctl create-keys`, a dataset
  for `/var/lib/sbctl`, and importing `modules/secure-boot.nix`.
- **`/var/lib/ncps`** is its own dataset with a 560G quota behind ncps' 500G LRU
  budget; the LRU sweep now actually runs (nightly 03:00).
- **`backup-vaultwarden.service` fails on the first boot** and keeps failing
  until the vault is restored. Not a config problem: nixpkgs' backup script ends
  with `cp -r "$DATA_FOLDER"/!(db.*)`, unguarded, so it exits 1 whenever the data
  dir holds nothing but `db.*` — i.e. a brand-new vault. It clears itself as soon
  as the directory has any other file (`rsa_key.pem`, attachments), which Phase 4
  provides. Verified in `orchid-vm`; the sqlite backup itself runs fine.
