# orchid — ZFS-on-LUKS reinstall runbook

New tower: Ryzen 7 7800X3D, 64 GiB, discrete AMD GPU (amdgpu +
LACT, `modules/hardware/gpu-amd.nix`), no dedicated NIC. A **clean install** —
nothing is carried over from the old box. End state: **ZFS-on-LUKS** on a single NVMe, **tmpfs root + impermanence**,
systemd-boot (no Secure Boot), CachyOS LTS `zen4` kernel, **headless** — no rice,
no compositor, no greeter.

Same shape as tempest, minus lanzaboote and ucodenix. The reasoning behind the
layout is [`adr/0001-zfs-on-luks-tempest.md`](adr/0001-zfs-on-luks-tempest.md);
this file is just the procedure. Layout: [`../disks/orchid.nix`](../disks/orchid.nix).

---

## Phase 0 — Rehearse it in a VM (optional, free)

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

Build the installer ISO on tempest (`hosts/installer`: stock minimal ISO + flakes,
sshd up with irene's key, this repo baked in at `/etc/source-of-truth`) and
write it to a USB stick:

```sh
nix build .#nixosConfigurations.installer.config.system.build.isoImage -o result-iso
sudo dd if=result-iso/iso/nixos-*.iso of=/dev/disk/by-id/usb-<stick> bs=4M status=progress oflag=sync
```

Boot orchid from it with ethernet plugged in, then from tempest
`ssh root@nixos.local` (the ISO publishes itself over mDNS; tempest resolves
it via avahi), and:

```sh
cp -rL /etc/source-of-truth ~/source-of-truth && cd ~/source-of-truth
```

Work from a copy, not `/etc/source-of-truth` itself: that is a symlink into
`/nix/store`, and `nix run` refuses to run with its cwd inside the store
("installable '/nix/store/…-source' does not correspond to a Nix language
value"), which breaks both `disk-format` and `disk-install`.

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

## Phase 4 — Finish

The root FS is tmpfs: everything below either lands on a ZFS dataset or is
bind-mounted from `/persist` (`hosts/orchid/system/persistence.nix`).

Push the repo (nh's flake path) from tempest rather than cloning on orchid — a
fresh box has no GitHub key, and the tree carries the git-crypt'd `passwords`
file, which only an unlocked checkout can evaluate:

```sh
# on orchid
sudo install -d -o irene -g users /persist/source-of-truth

# on tempest
rsync -a /persist/source-of-truth/ orchid:/persist/source-of-truth/
```

Then on orchid:

```sh
nix run /persist/source-of-truth#home-manager -- switch --flake '.#irene@orchid' -b backup
sudo tailscale up --advertise-exit-node
```

Then check: `zpool status`, `systemctl --failed`, `sitrep`.

**Leave the vault mirrors alone.** tempest and hydra still hold the old vault
and pull from orchid as `vwbackup@orchid`; their stored host key for orchid is
now stale, so the pull fails. That is what keeps them from syncing orchid's
empty vault over their copy — don't clear orchid's line from
`/var/lib/vaultwarden-mirror/ssh/known_hosts` until orchid has a vault worth
mirroring.

Daily driving is `apply` (= `nh os switch && nh home switch -b backup`).

---

## Known follow-ups

- **No NIC config.** `networking.useDHCP` is left at its default, so whatever
  interface appears comes up on DHCP. The old `defaultGateway = 10.0.0.1` and
  the static `enp4s0f0` block are gone.
- **No fonts** — add them with the rice when a WM comes back (`rices/estradiol` is still in the tree, imported by nothing).
- **Secure Boot** is not set up. Adding it means `sbctl create-keys`, a dataset
  for `/var/lib/sbctl`, and importing `modules/secure-boot.nix`.
- **`/var/lib/ncps`** is its own dataset with a 560G quota behind ncps' 500G LRU
  budget; the LRU sweep now actually runs (nightly 03:00).
- **`backup-vaultwarden.service` fails on the first boot** and keeps failing
  while the vault is empty. Not a config problem: nixpkgs' backup script ends
  with `cp -r "$DATA_FOLDER"/!(db.*)`, unguarded, so it exits 1 whenever the data
  dir holds nothing but `db.*` — i.e. a brand-new vault. It clears itself as soon
  as the directory has any other file (`rsa_key.pem`, attachments). Verified in `orchid-vm`; the sqlite backup itself runs fine.
- **Credential-backed units fail until their secrets exist.** Nothing is in
  `/persist` on a clean install, so the borg jobs
  (`/persist/borg-*-backup/passphrase` + `/home/irene/.ssh/id_ed25519`), caddy
  (`/persist/caddy/env`), and the bots (`/persist/diapee-bot`,
  `/persist/auxologico-check` `env` files) stay red in `systemctl --failed`
  until those files are created. Syncthing gets a new device identity, so every
  peer has to be re-paired.
