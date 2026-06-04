# tempest — migrazione USB → NVMe (reinstall + `zfs send`, **senza live CD**)

Spostare il sistema ZFS che gira **ora sulla SanDisk USB** sul **Corsair MP700
PRO SE (NVMe)** con una reinstall pulita e una replica ZFS dei dati. Il *perché*
dello stack (ZFS-on-LUKS, lanzaboote, TPM2/PCR 7, tmpfs-root) è in
[`adr/0001-zfs-on-luks-tempest.md`](adr/0001-zfs-on-luks-tempest.md).

**Si fa tutto dal sistema USB in esecuzione** — niente live CD. È possibile
perché il pool target ha un nome **diverso** dal pool vivo:

- pool vivo (USB) = **`zroot`** · pool nuovo (Corsair) = **`rpool`**

Nomi diversi → `disko` può fare `zpool create rpool` mentre `zroot` è importato,
e il `zfs send zroot → rpool` non collide. (Se i nomi coincidessero,
`zpool create` fallirebbe con "pool already exists" e servirebbe un live CD.)

## Perché `zfs send` e non `dd`

- Sposta **~920 G di dati reali** (pool pieno al 53%), non i 2 TB di ciphertext
  che `dd` copierebbe.
- Pool nuovo → **GUID nuovo**, **4K LBA nativo** sul Corsair (`--lbaf=1`).
- I **secret in `/persist/secrets`** arrivano dentro lo stream → niente copia a
  mano.
- Costo: vanno **rifatti Secure Boot + TPM** (il LUKS è nuovo).

## Mappa dischi + nomi (verificati)

| Ruolo | Device by-id | pool / LUKS / VG |
|------|--------------|------------------|
| **Sorgente** (USB, vivo, da svuotare alla fine) | `usb-SanDisk_Portable_SSD_323532353952343031333638-0:0` | pool `zroot` · LUKS `tcrypt` · VG `tpool` |
| **Vecchia btrfs** (sul Corsair, da cancellare; ora in `/mnt/old`) | `nvme-Corsair_MP700_PRO_SE_A8WFB416001JKK` | LUKS `cryptlvm` · VG `pool` |
| **Target** (install nuovo sul Corsair) | `nvme-Corsair_MP700_PRO_SE_A8WFB416001JKK` | pool `rpool` · LUKS `crypt` · VG `pool` · disko `main` |

Entrambi i dischi 2 TB. Il Corsair espone **LBA Format 1 = 4096 byte** ("Best").

> ⚠️ **NON fare `system-apply` / `nixos-rebuild` sulla USB** dopo questi edit.
> La USB ha su disco i nomi vecchi (`zroot`/`tcrypt`/`tpool`/`disk-master-*`); la
> config rinominata (`rpool`/`crypt`/`pool`/`main`) si materializza **solo** col
> fresh install sul Corsair. Un rebuild della USB romperebbe il suo prossimo boot.
> La USB resta comunque bootabile (generazione attuale) come fallback finché non
> la svuoti — utile se l'NVMe non parte.

> ⚠️ Per la migrazione si usa **`tempest-install <device>`** (fa anche
> `nixos-install`), non `tempest-format <device>`. Entrambi ora richiedono il
> device esplicito come argomento — nessun device di default, così un lancio
> accidentale non formatta il disco sbagliato.

---

## Phase 0 — Prep (dal sistema USB)

```sh
cd /persist/source-of-truth
borg list ssh://u518612@u518612.your-storagebox.de:23/./backups/tempest-home-irene | tail
```

Il device si passa come argomento a `tempest-install` (i nomi sono già
`main`/`crypt`/`pool`/`rpool`); non c'è più nessun campo `device` da editare in
`disks/tempest.nix`. Il target è il Corsair:

```sh
# /dev/disk/by-id/nvme-Corsair_MP700_PRO_SE_A8WFB416001JKK
git add -A && git commit -m "tempest: ..."   # opzionale, NON rebuildare la USB
```
(Committare è opzionale: `disko-install` builda anche un flake "sporco". Ma
**non** lanciare `system-apply`.)

---

## Phase 1 — Libera l'NVMe (dal sistema USB)

La vecchia btrfs sul Corsair va smontata e i suoi layer chiusi, così la namespace
è libera per `nvme format` / disko. (Verifica i nomi con `lsblk -f` prima.)

```sh
sudo umount -R /mnt/old 2>/dev/null
sudo swapoff /dev/pool/swap 2>/dev/null     # vecchio swap NVMe, se attivo
sudo vgchange -an pool                       # disattiva la VECCHIA VG sul Corsair
sudo cryptsetup close cryptlvm 2>/dev/null   # chiudi il VECCHIO LUKS sul Corsair
lsblk /dev/nvme0n1                           # nessun figlio → namespace libera
```
> `vgchange -an pool` tocca solo la VG del Corsair: la USB usa `tpool`, il root
> vivo non dipende da `pool`. Nessun rischio sul sistema in esecuzione.

---

## Phase 2 — 4Kn + install sul Corsair (dal sistema USB)

```sh
sudo nvme format /dev/nvme0n1 --lbaf=1 --force   # 4Kn, DESTRUCTIVE: cancella la vecchia btrfs
lsblk -o NAME,LOG-SEC,PHY-SEC /dev/nvme0n1       # atteso 4096/4096

cd /persist/source-of-truth
./tempest-install /dev/disk/by-id/nvme-Corsair_MP700_PRO_SE_A8WFB416001JKK
# disko fa destroy→format→mount del Corsair + nixos-install. Crea il pool `rpool`
# (nessuna collisione con lo `zroot` vivo). Prompt LUKS → passphrase FORTE:
# è il fallback permanente una volta arruolato il TPM. Non perderla.
```
A fine install esiste `rpool` sul Corsair, importato accanto a `zroot` (USB).
**Non riavviare ancora** — prima la replica dei dati.

---

## Phase 3 — Replica `/persist` (+ `/home`) dal pool vivo

Snapshot del pool vivo, poi sostituisci il `persist` vuoto creato dall'install:

```sh
sudo zfs snapshot -r zroot/persist@migrate          # snapshot immutabile del pool USB vivo

sudo zpool export rpool 2>/dev/null
sudo zpool import -N -R /mnt rpool                  # importato, niente montato
sudo zfs destroy -r rpool/persist                   # via il persist/home freschi e vuoti
sudo zfs send -Rv zroot/persist@migrate | sudo zfs recv -s -u rpool/persist

sudo zfs list -r rpool                              # rpool/persist e .../home presenti
```
Note:
- `-Rv` ricorsivo+progress (porta `persist` **e** il figlio `home`, snapshot e
  proprietà); `recv -s` abilita il **resume token**; `-u` non monta.
- **NON** si replica `rpool/nix` (ricostruito dall'install) né `rpool/sbctl`
  (chiavi rigenerate in Phase 5). Solo `persist` (include `/persist/secrets`,
  vaultwarden, grafana, NetworkManager…) e `home`.
- ~920 G letti dalla USB lenta: qualche ora, e il sistema sarà un po' fiacco
  (legge dal proprio root USB). Monitora la temperatura del Corsair in scrittura:
  `watch -n5 'sudo nvme smart-log /dev/nvme0n1 | grep -i temperature'`.
- **Se si interrompe**, riprendi dal token:
  ```sh
  tok=$(sudo zfs get -H -o value receive_resume_token rpool/persist)
  sudo zfs send -t "$tok" | sudo zfs recv -s -u rpool/persist
  ```

---

## Phase 4 — Send incrementale del delta (subito prima del reboot)

Dato che hai continuato a usare il sistema durante il send lungo, cattura ciò che
è cambiato in `/persist` dopo `@migrate`. (Idealmente ferma prima i writer pesanti.)

```sh
sudo zfs snapshot -r zroot/persist@migrate2
sudo zfs send -Rv -i @migrate zroot/persist@migrate2 | sudo zfs recv -F -s -u rpool/persist
sudo zpool export rpool                              # export pulito prima del reboot
```
È veloce (solo il delta). Se non hai usato il sistema, puoi saltarla.

---

## Phase 5 — Reboot nel Corsair + Secure Boot + TPM

Riavvia e seleziona il **Corsair** nel boot menu del firmware (l'entry EFI l'ha
scritta `--write-efi-boot-entries`). La USB resta come fallback bootabile.
Inserisci la **nuova** passphrase LUKS (TPM non ancora arruolato).

```sh
zpool status                  # rpool ONLINE
zfs list                      # rpool/persist, rpool/persist/home popolati
ls /persist/home/irene        # i tuoi dati ci sono
findmnt /persist /persist/home /nix
```

Poi, **nell'ordine** (l'ordine è load-bearing):

```sh
# 5a. Chiavi Secure Boot (sul dataset rpool/sbctl)
sudo sbctl create-keys && sudo sbctl status

# 5b. Passa a lanzaboote: scommenta in hosts/tempest/default.nix
#       ../../modules/secure-boot.nix      (mkForce-disabilita systemd-boot)
sudo nixos-rebuild boot --flake .#tempest  # builda e FIRMA la UKI
sudo sbctl verify                          # ESP files "signed"
# reboot → confermi boot via lanzaboote (ancora con passphrase)

# 5c. Abilita Secure Boot nel firmware: BIOS → Security → Secure Boot →
#     erase keys (Setup Mode) → save & exit → riboota
sudo sbctl enroll-keys --microsoft         # tue chiavi + Microsoft
# BIOS → ENABLE Secure Boot → save & exit
bootctl status                             # "Secure Boot: enabled (user)"

# 5d. SOLO ORA (PCR 7 finale) arruola il TPM. p2 = LUKS (p1 = ESP)
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme0n1p2
```
Reboot → unlock **silenzioso**; la passphrase resta come fallback.

---

## Phase 6 — Svuota la USB (solo dopo aver verificato il Corsair)

Finché il Corsair non boota e i dati non sono verificati, **lascia stare la USB**:
è il tuo rollback (basta selezionarla nel boot menu — userà la passphrase, perché
abilitare Secure Boot ha cambiato PCR 7 e il TPM-unlock della USB non vale più).

Quando sei sicura, dal sistema sul Corsair azzera la SanDisk:

```sh
sudo vgchange -an tpool 2>/dev/null
sudo cryptsetup close tcrypt 2>/dev/null
sudo wipefs -a /dev/disk/by-id/usb-SanDisk_Portable_SSD_323532353952343031333638-0:0
sudo sgdisk --zap-all /dev/disk/by-id/usb-SanDisk_Portable_SSD_323532353952343031333638-0:0
```
Pronta come disco di backup (fs a scelta).

Opzionale: i moduli `uas`/`usb_storage` in `system/boot.nix` erano "REQUIRED"
solo col root su USB — ora superflui (innocui), puoi ripulirli a parte.

---

## Checklist finale

- [ ] `zpool status -x` → "all pools are healthy"
- [ ] `zfs list` → `rpool/persist` ~845 G, `rpool/persist/home` popolato
- [ ] `/persist/secrets`, vaultwarden, NetworkManager, tailscale presenti
- [ ] `lsblk -o NAME,LOG-SEC,PHY-SEC /dev/nvme0n1` → 4096/4096
- [ ] `bootctl status` → Secure Boot enabled (user)
- [ ] Reboot silenzioso (TPM); passphrase LUKS come fallback
- [ ] `systemctl status sanoid.timer smartd` attivi; `zfs list -t snapshot` popola
- [ ] Hibernate test: `systemctl hibernate`, resume, poi `zpool status` pulito
- [ ] borg gira: `systemctl start borgbackup-job-home-irene.service`
- [ ] USB azzerata e riformattata come backup

## Gotcha riassunti

- **Nome pool diverso (`rpool` vs `zroot`)** è ciò che permette tutto da USB: niente
  collisione `zpool create`, niente `oldroot`, niente live CD.
- **VG `pool` del Corsair**: la vecchia (btrfs) e la nuova hanno lo stesso nome ma
  stanno sullo stesso disco e in sequenza — la vecchia va disattivata/cancellata
  (Phase 1 / `nvme format`) prima che disko crei la nuova. La USB usa `tpool`,
  quindi nessun conflitto incrociato.
- **Non rebuildare la USB** con la config rinominata: si applica solo all'install
  sul Corsair.
- **Non svuotare la USB** finché il Corsair non è verificato (è il fallback).
- **TPM dopo Secure Boot**, sempre: abilitare SB cambia PCR 7.
