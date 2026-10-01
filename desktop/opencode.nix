# opencode, pointed at orchid's llama-server (hosts/orchid/system/llm.nix) over
# the tailnet. Imported by the tempest and orchid homes; the ocelot guest gets
# the same file because scripts/ocelot.sh binds ~/.config/opencode into it.
{...}: let
  # The .ts.net name, not plain `orchid`: that resolves to orchid's LAN
  # addresses, and llm.nix opens :8080 on tailscale0 only.
  baseURL = "http://orchid.boreal-city.ts.net:8080/v1";
  limit = {
    context = 131072; # llm.nix ctx-size
    output = 32768;
  };
in {
  programs.opencode = {
    enable = true;
    # Installed by desktop/cli-packages.nix (llm-agents tracks upstream closer
    # than nixpkgs), which the ocelot guest shares; this module only writes the
    # config.
    package = null;

    settings = {
      provider.orchid = {
        npm = "@ai-sdk/openai-compatible";
        name = "orchid (llama.cpp)";
        options = {inherit baseURL;};
        # One model served twice: llama-server answers to any model name, so
        # the second entry differs only in turning Qwen's thinking off, per
        # request, through the chat template. opencode sends no sampling
        # parameters of its own, so the thinking entry gets the server's
        # (Qwen's thinking-mode values, in llm.nix); `options` go into the
        # request body verbatim, which is how the second one gets Qwen's
        # non-thinking values instead. The presence penalty is what keeps it
        # from repeating the same tool call in a loop.
        models = {
          "qwen3.6-35b-a3b" = {
            name = "Qwen3.6 35B-A3B";
            inherit limit;
          };
          "qwen3.6-35b-a3b-no-think" = {
            name = "Qwen3.6 35B-A3B (no thinking)";
            inherit limit;
            options = {
              chat_template_kwargs.enable_thinking = false;
              temperature = 0.7;
              top_p = 0.8;
              presence_penalty = 1.5;
            };
          };
        };
      };
      model = "orchid/qwen3.6-35b-a3b";
      # Session titles and summaries: short, and not worth a think each.
      small_model = "orchid/qwen3.6-35b-a3b-no-think";
      # Generation is ~75% of a turn on orchid and much of it is reasoning,
      # so the read-only search subagent skips it: finding files doesn't
      # need it. build, plan and general (which can edit) keep thinking.
      agent.explore.model = "orchid/qwen3.6-35b-a3b-no-think";
    };
  };
}
