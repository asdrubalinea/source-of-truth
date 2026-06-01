# Crash Report — BTRFS Filesystem Forced Read-Only

**Date analyzed:** 2026-06-01
**Source:** `crash_log` (dmesg, single boot session)
**System:** CachyOS, kernel `7.0.9-cachyos-lto`, AMD GPU (`amdgpu`), ChromeOS EC present (`cros-ec-dev` → likely Framework/Chromebook-class laptop)
**Affected device:** `dm-2` (device-mapper — LUKS/LVM in the storage stack)
**Filesystem:** BTRFS (single device, DUP metadata)

---

## Summary

The BTRFS filesystem on `dm-2` carried **pre-existing metadata corruption that was already present at mount time**. For ~2.5 hours the filesystem ran read-write while harmlessly logging read errors against the damaged metadata. It was finally forced **read-only** when a *write* operation (creating a new file) had to modify the metadata tree through a corrupted node, causing a transaction abort. The read-only flip was BTRFS protecting itself, not the root cause.

**Root cause: lost writes** (a flush/FUA barrier not honored, or an unclean power-off) — **not** failing drive hardware.

---

## Timeline

| Kernel time | Event |
|-------------|-------|
| +69s | `systemd-journald: Journal file corrupted, rotating` — first hint of trouble |
| +77s | First corruption errors: `parent transid verify failed on logical 1450719019008 ... wanted 709692 found 708663` (both mirrors) |
| +1030s | Second damaged block surfaces: `bytenr=1824568410112 ... wanted 607134 found 607006` + `tree first key mismatch` |
| +77s → +9003s | Same read errors recur whenever the damaged blocks are read; filesystem stays mounted **read-write** |
| **+9003s (~2h30m)** | `btrfs_create_new_inode` → `btrfs_add_link` tries to modify metadata through the bad node → `Transaction aborted (error -5)` → **`forced readonly`** |

---

## Evidence

### Two distinct damaged metadata blocks

**Block A — `logical 1450719019008`** (the one that triggered read-only):
```
BTRFS error (device dm-2): parent transid verify failed on logical 1450719019008 mirror 1 wanted 709692 found 708663
BTRFS error (device dm-2): parent transid verify failed on logical 1450719019008 mirror 2 wanted 709692 found 708663
```
- On-disk block holds generation **708663**; the parent pointer expects **709692**. The newer write to this child block never landed.
- **Both DUP mirrors are identically stale** (both `found 708663`) — rules out a single bad sector.
- No b-tree key is printed for this block, so no inode is recoverable from it.

**Block B — `bytenr=1824568410112` / `logical 1824568393728`:**
```
BTRFS error (device dm-2): tree first key mismatch detected, bytenr=1824568410112 parent_transid=607006
    key expected=(29253883,12,2176737527) has=(29253883,12,29253879)
BTRFS error (device dm-2): parent transid verify failed on logical 1824568393728 wanted 607134 found 607006
```
- Decoding the key `(objectid, type, offset)`:
  - `objectid = 29253883` → **inode number** of the affected object
  - `type = 12` → `INODE_REF` (links an inode into its parent directory)
  - `offset = 29253879` (on-disk) / `2176737527` (expected) → **parent directory inode**
- The two inode numbers being 4 apart indicates the file and its directory were created in the same burst (file lives directly in that dir).

### The forced read-only

```
BTRFS error (device dm-2 state A): Transaction aborted (error -5)
BTRFS: error (device dm-2 state A) in btrfs_add_link:6936: errno=-5 IO failure
BTRFS info (device dm-2 state EA): forced readonly
BTRFS: error (device dm-2 state EA) in btrfs_create_new_inode:6872: errno=-5 IO failure
```

---

## Diagnosis

- **What broke:** BTRFS metadata, not the drive. `parent transid verify failed` means a tree node points to a child block at generation *N*, but the block on disk still holds an older generation — the newer write was lost.
- **Why lost-writes, not bad media:**
  1. **No block-layer I/O errors anywhere in the log** — no `ata`, `nvme`, `scsi`, or `blk_update_request` failures. The drive reads fine.
  2. **Both DUP mirror copies are identically stale.** A failing sector corrupts one copy; both holding the same old data means the writes never reached either copy.
  3. Multiple blocks from different generations affected — consistent with write reordering / unhonored flush over time.
- **Likely trigger:** a prior unclean shutdown / power loss / hard reset while writes were in flight, on storage (SSD/NVMe, or especially a USB/Thunderbolt enclosure) that does not honor flush/FUA barriers.
- **Why the whole fs went read-only (not just one file):** BTRFS metadata is shared b-trees. On an unreconcilable transaction error it aborts and freezes *all* writes to prevent localized corruption from spreading. This is by design (ext4's default `errors=remount-ro` behaves the same). Reads never trigger this — only writes through the damaged tree do.

---

## Impact

- **Data is intact and fully readable.** Only writes that traverse the damaged metadata fail; everything else reads normally.
- The read-only state is **per-mount-session** — a reboot remounts read-write (until the next write hits the bad node). Not a brick.
- The affected named object identifiable from the log is **inode 29253883** (parent dir inode **29253879**). The file whose creation triggered the read-only was brand-new and unnamed on disk, so it cannot be identified.

---

## Recommended Recovery (back up before any repair)

1. **Boot from a live USB.** Open LUKS, then identify the device:
   ```bash
   lsblk -f
   sudo btrfs filesystem show
   ```
2. **Mount read-only and rescue data first:**
   ```bash
   sudo mount -o ro,rescue=all /dev/mapper/YOURDEV /mnt
   # if that fails, try the previous tree root:
   sudo mount -o ro,rescue=usebackuproot /mnt
   ```
   Copy everything important off now.
3. **If it won't mount, extract without mounting:**
   ```bash
   sudo btrfs restore -v /dev/mapper/YOURDEV /destination
   ```
4. **Assess (read-only, safe):**
   ```bash
   sudo btrfs check --readonly /dev/mapper/YOURDEV
   ```
5. **Check the drive is actually healthy (it most likely is):**
   ```bash
   sudo smartctl -a /dev/nvmeX   # or /dev/sdX
   ```
   Zero reallocated/pending sectors + zero media errors → reuse the same drive.
6. **Repair, only after a backup, in increasing risk:**
   ```bash
   sudo btrfs rescue zero-log /dev/mapper/YOURDEV   # safe; only if log-tree is the issue
   sudo btrfs check --repair /dev/mapper/YOURDEV    # risky with transid corruption
   ```
   For lost-write transid corruption, `--repair` often cannot reconstruct the missing newer block. If it doesn't take: **rescue data → `mkfs.btrfs` → restore** is the guaranteed path to a working system.

### Resolve the affected inode to a path (after mounting read-only)
```bash
sudo btrfs inspect-internal inode-resolve 29253883 /mnt   # the file/dir
sudo btrfs inspect-internal inode-resolve 29253879 /mnt   # its parent directory
# inode numbers are per-subvolume; point /mnt at the right subvol, or:
sudo find /mnt -inum 29253883 2>/dev/null
```

---

## Prevention

- **You almost certainly do not need a new drive** — confirm with `smartctl`, then wipe and reuse.
- Identify and fix the source of the unclean writes: crash, forced power-off, suspend/resume storage bug, or a flaky external enclosure (enclosures are a common cause of dropped flushes and should not host a root filesystem).
- Run periodic `sudo btrfs scrub start /` to catch corruption early, while it's still a single block.
- Keep real backups — DUP metadata does **not** protect against lost writes, since the write never reaches either copy.

---

## Key Facts at a Glance

| Item | Value |
|------|-------|
| Failure mode | Forced read-only after metadata transaction abort (`errno -5`) |
| Root cause | Lost writes (unhonored flush / unclean shutdown) |
| Hardware fault? | No evidence — zero block-layer I/O errors |
| Damaged block A | `logical 1450719019008`, gen wanted 709692 / found 708663 |
| Damaged block B | `bytenr 1824568410112`, gen wanted 607134 / found 607006 |
| Identifiable inode | 29253883 (parent dir inode 29253879) |
| Data readable? | Yes — full read-only recovery possible |
| Drive reusable? | Yes (pending `smartctl` confirmation) |
