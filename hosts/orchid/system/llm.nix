{pkgs, ...}: let
  modelsDir = "/persist/models";
  model = "${modelsDir}/Qwen3.6-35B-A3B-UD-Q4_K_S.gguf";
  port = 8080;
in {
  # Local LLM: llama-server on the 9070 XT (16 GiB) via Vulkan/RADV, with the
  # MoE experts that don't fit spilled to DDR5. Web UI + OpenAI-compatible API
  # on :8080, reachable over tailscale only.
  #
  # Vulkan rather than ROCm: it needs nothing beyond the Mesa already enabled by
  # modules/hardware/gpu-amd.nix, and on RDNA4 it matches or beats HIP at token
  # generation. For ROCm instead: `rocmSupport = true; rocmGpuTargets =
  # ["gfx1201"];`. With no GGML_VK_VISIBLE_DEVICES, ggml's Vulkan backend uses
  # only the discrete GPU(s) when one exists, so the Raphael iGPU and llvmpipe
  # are skipped — the startup log should list GFX1201 alone.
  #
  # The model is fetched by hand; the unit is skipped until it exists:
  #   curl -L -o /persist/models/Qwen3.6-35B-A3B-UD-Q4_K_S.gguf \
  #     https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q4_K_S.gguf
  #
  # Q4_K_S rather than Q4_K_M: measured 2026-09-30 against Q8_0 on this repo's
  # text, its KL divergence is 0.049 vs 0.044 (same top token 93.9% vs 94.4%),
  # and its smaller CPU-side experts decode faster, ~45 vs ~42 t/s. Smaller
  # quants fit more layers on the card but cost quality: IQ4_XS (KLD 0.071)
  # decodes slower on the CPU; Q3_K_XL (KLD 0.085, 3× worse in the worst 1%)
  # is ~10% faster at tg and 50% at pp, but looped on tool calls in a long
  # agent session where Q4_K_S didn't.
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp.override {vulkanSupport = true;};

    # Long option names only: the module turns any multi-character key into
    # `--key`, so `ngl` would become `--ngl`, which llama-server rejects.
    settings = {
      inherit model port;
      host = "0.0.0.0";

      # Qwen3.6-35B-A3B is hybrid: only 10 of its 40 layers are full attention
      # (2 KV heads × 256 dim), the rest Gated DeltaNet with a fixed-size state.
      # 128K of KV is ~1.3 GiB at q8_0 (~2.5 GiB at bf16); the rest of the card
      # goes to expert weights.
      ctx-size = 131072;
      flash-attn = "on";
      # Unsloth recommends bf16 for this model because some setups produce
      # gibberish with quantised KV. Switch both to "bf16" if output degrades;
      # it costs ~1.2 GiB, i.e. about two layers' worth of experts.
      cache-type-k = "q8_0";
      cache-type-v = "q8_0";

      # All layers on the GPU, then the routed experts of the first N layers
      # back on the CPU, ~430 MiB of VRAM per layer. 17 is the lowest that
      # keeps 512 MiB free at 128K context with the speculation below (529
      # MiB after a full batch); 16 leaves ~100. Too low never OOMs: amdgpu
      # spills to GTT and the server loads "fine" but slow, so re-tune with
      # `llm-bench`, not by trial. Measured 2026-09-30: pp 1369, tg 46.8 t/s.
      n-gpu-layers = 99;
      n-cpu-moe = 17;

      # Large ubatch amortises streaming the CPU-side experts over PCIe during
      # prompt processing. 4096 is faster still at pp (1566 t/s) but its
      # compute buffer spills to GTT at n-cpu-moe 17 (tg 29.6), and buying
      # the room back costs two layers of experts, so 2048 is the better trade.
      batch-size = 4096;
      ubatch-size = 2048;
      # 7800X3D: 8 physical cores; SMT siblings don't help memory-bound decode.
      threads = 8;
      # Load the CPU-side experts into anonymous memory instead of page cache,
      # so they can't be evicted under memory pressure. (This is what
      # `--no-mmap` used to do; llama.cpp 0.4 replaced it with --load-mode.)
      load-mode = "none";

      # N-gram speculative decoding: drafts tokens by matching text already in
      # the context, so no draft model (this GGUF has no MTP layers either).
      # It pays off when the model copies context, as an agent rewriting a
      # file does, and never fires on new text at these settings.
      #
      # Tuned 2026-09-30 on six fixed file rewrites (greedy, thinking off):
      # no speculation 42 t/s; defaults (match 24, drafts 48–64) 74; these
      # 156, with prose unchanged at ~42. A shorter match is worse, not
      # better: at 8–16 it drafts on coincidental matches and even slows
      # prose. An n-max above 128 costs ~970 MiB of VRAM at load (a step,
      # not a slope: 128 → 256 adds it all), which the n-cpu-moe fit above
      # already pays for; 512 drafts were faster still (~190) but spilled.
      spec-type = "ngram-mod";
      spec-ngram-mod-n-match = 48;
      spec-ngram-mod-n-min = 96;
      spec-ngram-mod-n-max = 256;

      # Qwen's thinking-mode sampling defaults. For non-thinking mode, clients
      # pass chat_template_kwargs = {enable_thinking = false} per request (with
      # temp 0.7, top-p 0.8, presence-penalty 1.5).
      temp = 1.0;
      top-p = 0.95;
      top-k = 20;
      min-p = 0.0;
    };
  };

  systemd.services.llama-cpp = {
    # Without the model the server would exit 1 and restart-loop every 5 min.
    unitConfig.ConditionPathExists = model;
    # DynamicUser has no home, so RADV can't write its shader cache anywhere
    # and recompiles every pipeline on each start. The CacheDirectory the
    # module declares is on the tmpfs root, so this lasts one boot.
    environment.MESA_SHADER_CACHE_DIR = "/var/cache/llama-cpp";
  };

  # `llm-bench` stops the unit, re-tunes n-cpu-moe / ubatch-size / threads
  # against the card at the settings below, and writes a report under
  # ~/.local/state/llm-bench. Re-run it after changing the model or context.
  # `llm-stress` drives one opencode-shaped agent session against the server
  # and reports per-turn prefill, generation speed and cache hits as the
  # context grows; `--sweep` repeats it per server variant.
  environment.systemPackages = [
    (pkgs.callPackage ../../../packages/llm-bench.nix {})
    (pkgs.callPackage ../../../packages/llm-stress.nix {})
  ];

  # Directly on the persist dataset, so no impermanence bind is needed. It has
  # to be world-readable because the service runs as a DynamicUser.
  systemd.tmpfiles.rules = ["d ${modelsDir} 0755 irene users -"];

  # llama-server has no auth, so expose it on the tailnet only, not the LAN.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [port];
}
