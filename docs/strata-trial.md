# Strata on orchid: a trial of Qwen3.8-Flash-Next beside llama.cpp

**Status: paused 2026-10-05. Installed by hand under `/persist/strata`, not in
the flake. The first run ran orchid out of RAM before any benchmark; nothing in
`hosts/orchid/system/llm.nix` changed. Next step is the memory-budget test
below. Delete this file, `/persist/strata` and the `strata` distrobox if the
trial is dropped.**

## Why

[Strata](https://github.com/Niko1221/Strata) is its own ggml-based engine for
one model, Qwen3.8-Flash-Next (125B MoE, 512 experts per layer, 10 active),
at 2–3 bits. It caches *individual* experts in VRAM by routing frequency,
keeps all of them in RAM, and computes the uncached ones on the CPU in
parallel; MTP drafting plus prompt lookup on top. llama.cpp can't do the
per-expert part: each layer's experts are one tensor, so `n-cpu-moe` / `-ot`
only move whole layers.

Its RDNA4 numbers are from the same RX 9070 XT, on a weaker CPU (3900X, no
AVX-512, 47 GB):

| | decode short / 128K | prompt |
|---|---|---|
| Strata, Flash-Next IQ2_XS (125B) | 52 / 36 t/s | 1,110 t/s |
| orchid's llama-cpp, Qwen3.6-35B-A3B Q4_K_S | 46.8 t/s | 1,369 t/s |

Same speed class for ~3.5× the parameters. The point of the trial is whether
that holds on orchid and whether the quality is worth leaving llama.cpp.

The baseline to beat is `~/.local/state/llm-stress/20260930-165427` (q4ks,
100K target, thinking on): tg 43.0 t/s deep, 96.4 t/s on write_file, cold
prefill 1,084 t/s at 104K.

## What's installed

- `/persist/strata/Strata` — the repo (`6f32ec0`, engine 0.1.39), built for
  gfx1201 against ROCm 7.10.0a20251120 (AMD's TheRock wheels).
- `/persist/strata/Strata-data` — the IQ2_XS GGUFs (68 GB), the prepared pack,
  the MTP draft layer.
- Config `Strata/strata-iq2_xs.json`: 131072 context (= opencode's limit),
  int8 KV with KV streaming to RAM, images off, speed projection off.
- distrobox `strata`: Ubuntu 24.04, `/persist/strata` mounted, `/dev/kfd` and
  `/dev/dri` passed in.
- `/persist/strata/setup-1.log`, `setup.log`, `server.out`; the engine's own
  log is `Strata/strata-iq2_xs.log`.

Two NixOS-specific traps, both already worked around:

1. **distrobox inherits the host `PATH`**, so `setup.sh` built `.venv` with the
   Nix Python 3.14 from `~/.nix-profile`, whose pip numpy can't find
   `libstdc++`. Always enter with a clean path:
   `distrobox enter strata -- env PATH=/usr/local/bin:/usr/bin:/bin …`.
2. The engine was compiled against the ROCm in that first venv, and
   `engine/BUILD.json` records those `python3.14` lib dirs. The broken venv
   was moved to `/persist/strata/venv-nixpy-broken` and its `lib/python3.14`
   is **symlinked into the new venv** — don't delete it, or the engine loses
   `libamdhip64` / `libhipblas`. A clean fix is to delete `engine/BUILD.json`
   and rerun setup (ROCm reinstall + ~15 min rebuild).

Setup also warned there is no hipBLASLt tuning table for gfx1201 with
hipBLASLt 1.2.0, so prompts use plain hipBLAS (a bit slower prefill, same
answers).

## What happened on the first run

- Load: 33 GiB of experts into RAM, then 7,477 experts (10 GiB) into the
  expert cache, leaving **564 MiB of VRAM** beside the desktop.
- With the desktop's apps and the 16 GiB ARC cap, RAM ran out: kernel `page
  allocation failure`s 11:51–11:55 (kswapd, one in chrome), ~10 GB into swap.
  No OOM kill.
- The default memlock limit is 8 MiB, so `mlock` of the experts failed (it
  falls back silently) and part of them was swapped out. The first request
  stalled — "0 layers served" for 82 s — and Strata's watchdog killed the
  engine (exit -6). Stopped by hand while it reloaded.

## Does it fit headless?

Measured: system services 0.3 GiB; the desktop session was most of the rest
(browsers). The compositor itself is small. Budget on 61.9 GiB:

| | GiB |
|---|---:|
| Strata engine + server (35.6 GiB resident measured, + KV, slack) | ~38 |
| kernel, slab, services | ~3 |
| ARC at the current 16 GiB cap | 16 |
| **total** | **~57** |

So ~5 GiB slack as configured; ~13 GiB with the ARC capped at 8 GiB. Needs
`LimitMEMLOCK=infinity` so the experts can't swap. Headless also frees ~3.2 GB
of VRAM, about 2,200 more cached experts (~700 per GB), which should make it
faster than the first run would have been. Not going headless may be enough:
no browsers while it runs, or the desktop moved to the Raphael iGPU (frees the
VRAM, not the RAM).

Stays true either way: IQ3_XXS (~43 GiB experts) only fits with the ARC
squeezed hard; win11 (24 GiB + the card) and Strata can't run together, and
the VM's start hook would need to stop Strata like it stops llama-cpp; big nix
builds during a session will compete for RAM.

## Next: the memory-budget test

Without going headless:

1. Close the browsers on orchid; `systemctl is-active llama-cpp` → inactive.
2. Cap the ARC for this boot only:
   `echo $((8 * 2**30)) | sudo tee /sys/module/zfs/parameters/zfs_arc_max`
3. Start with memlock lifted (from the host, so the limit applies):
   ```sh
   sudo systemd-run --uid=irene -p LimitMEMLOCK=infinity --unit=strata-trial \
     distrobox enter strata -- env PATH=/usr/local/bin:/usr/bin:/bin \
     bash -c 'cd /persist/strata/Strata && exec .venv/bin/python serve/server.py \
       --engine strata --config strata-iq2_xs.json --port 8080'
   ```
   Untested as written: rootless podman needs the user's runtime dir, so add
   `-E XDG_RUNTIME_DIR=/run/user/1000` if distrobox can't find the container.
   Wait for `curl -s localhost:8080/health` to say `"loaded": true`, and check
   `strata-iq2_xs.log` no longer says the mlock failed — that's the proof the
   limit reached the engine inside the container.
4. `llm-stress --url http://127.0.0.1:8080 --target 100K`. Strata returns
   llama.cpp-style `timings`, so the script works unchanged. Compare with the
   baseline above.
5. Then a few real opencode tasks: speed only settles half the question. Point
   a provider at `http://orchid.boreal-city.ts.net:8080/v1` (Strata ignores
   the model name; thinking via `reasoning_effort`). It listens on 127.0.0.1
   by default; for the tailnet it needs `--host 0.0.0.0` **and** an API key.

Fallback if IQ2_XS still doesn't fit: the **Coder** pack (`./setup.sh --setup
--family coder`): 256 of 512 experts kept, chosen on code/agentic data, ~23 GiB
of experts, 91% of the full model's SWE-bench Verified by its authors. ~30 GB
download; it reuses the lookup table already on disk. Weaker outside code and
in non-English text.

If the desktop stays on the 9070 XT, `./setup.sh --vram-reserve-mib 3072`
keeps more VRAM free for it (the expert cache gets ~2.3 GB less).

## If it wins

It becomes a NixOS unit rather than a distrobox: either an FHS env around the
built tree or a real derivation (CMake + HIP against `rocmPackages`, plus the
Python server), `LimitMEMLOCK=infinity`, `ConditionPathExists` on the pack,
not wanted at boot (as llm.nix does for llama-cpp), a tailnet-only port with an
API key, and `desktop/opencode.nix` repointed. Expect the hipBLASLt table and
the pinned ROCm version to be the friction.

## Smaller ideas from Strata for the current llama.cpp setup

Flags confirmed present in llama-cpp 0.4.1:

- `--sleep-idle-seconds` — Strata's `idle_unload`: the unit could be wanted at
  boot again and give the VRAM back when idle, so opencode on tempest doesn't
  need a manual `systemctl start`.
- `--api-key-file` — the server is open to the whole tailnet today.
- `--spec-type` takes a list including `draft-mtp`: `draft-mtp,ngram-mod` is
  Strata's MTP + prompt-lookup combination, if a Qwen3.6-35B-A3B GGUF that
  keeps the MTP head exists (the current one doesn't).
