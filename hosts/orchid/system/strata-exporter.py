#!/usr/bin/env python3
"""Publish Strata's GET /metrics as Prometheus text for the node-exporter textfile collector.

Strata (the LLM server in /persist/strata, run as the `strata-trial` unit inside the
`strata` distrobox) answers GET /metrics with JSON: the engine's facts, what it is doing
right now, the last requests and running totals. node-exporter's textfile collector only
reads Prometheus text files, so this loop polls the JSON every few seconds and rewrites
<dir>/strata.prom atomically. Nothing but the standard library, no Strata import.

Counters come from the server's `totals` block and reset when the server restarts;
rate() in PromQL handles that. `strata_up` is 0 while the server is down or loading,
and every other series is dropped from the file so Prometheus marks it stale.
"""

import argparse
import json
import os
import sys
import tempfile
import time
import urllib.request


def esc(s):
    return str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


class Out:
    def __init__(self):
        self.lines = []

    def gauge(self, name, value, labels=None, help_=None):
        self.add(name, value, labels, help_, "gauge")

    def counter(self, name, value, labels=None, help_=None):
        self.add(name, value, labels, help_, "counter")

    def add(self, name, value, labels, help_, kind):
        if value is None:
            return
        if isinstance(value, bool):
            value = int(value)
        try:
            value = float(value)
        except (TypeError, ValueError):
            return
        if help_:
            self.lines.append(f"# HELP {name} {help_}")
        self.lines.append(f"# TYPE {name} {kind}")
        lab = ""
        if labels:
            lab = "{" + ",".join(f'{k}="{esc(v)}"' for k, v in labels.items()) + "}"
        self.lines.append(f"{name}{lab} {value:g}")

    def text(self):
        return "\n".join(self.lines) + "\n"


def render(d):
    o = Out()
    o.gauge("strata_up", 1, help_="1 while Strata answers GET /metrics")

    eng = d.get("engine") or {}
    o.gauge("strata_info", 1, {"model": eng.get("model", ""), "version": eng.get("version", "")},
            "Model and engine version")
    o.gauge("strata_engine_context_max_tokens", eng.get("context") or eng.get("max_context"))
    o.gauge("strata_engine_kv_resident_tokens", eng.get("kv_resident"))
    o.gauge("strata_engine_expert_slots", eng.get("expert_slots"), help_="Experts cached in VRAM")
    mib = eng.get("expert_cache_mib")
    o.gauge("strata_engine_expert_cache_bytes", mib * 2**20 if mib is not None else None)
    mib = eng.get("vram_free_mib")
    o.gauge("strata_engine_vram_free_bytes", mib * 2**20 if mib is not None else None)
    mib = eng.get("arena_mib")
    o.gauge("strata_engine_arena_bytes", mib * 2**20 if mib is not None else None,
            help_="Experts resident in RAM")
    o.gauge("strata_engine_spec_tokens", eng.get("spec"), help_="Draft tokens per step")

    live = d.get("live") or {}
    state = live.get("state") or "idle"
    phase = live.get("phase") or ""
    o.gauge("strata_live_state", 1, {"state": state, "phase": phase},
            "What the server is doing now; one series, labels change")
    o.gauge("strata_live_generating", 1 if state == "generating" else 0)
    o.gauge("strata_live_queued", live.get("queued"))
    o.gauge("strata_live_tokens_per_second", live.get("tok_s"),
            help_="Generation rate over the last couple of seconds; 0 while idle")
    o.gauge("strata_live_tokens_per_second_mean", live.get("tok_s_mean"),
            help_="Generation rate averaged over the current request")
    o.gauge("strata_live_prefill_tokens_per_second_mean", live.get("prefill_tok_s_mean"))
    o.gauge("strata_live_prompt_tokens", live.get("prompt_tokens"), help_="Context of the current request")
    o.gauge("strata_live_generated_tokens", live.get("generated"))
    o.gauge("strata_live_max_tokens", live.get("max_tokens"))
    o.gauge("strata_live_elapsed_seconds", live.get("elapsed_s"))

    t = d.get("totals") or {}
    o.gauge("strata_totals_since_timestamp_seconds", t.get("since"))
    o.counter("strata_requests_total", t.get("requests"))
    o.counter("strata_prompt_tokens_total", t.get("prompt_tokens"), help_="Prompt tokens, reused ones included")
    o.counter("strata_prompt_reused_tokens_total", t.get("reused"), help_="Prompt tokens served from the KV cache")
    o.counter("strata_output_tokens_total", t.get("output_tokens"))
    ms = t.get("prompt_ms")
    o.counter("strata_prompt_seconds_total", ms / 1000 if ms is not None else None,
              help_="Time spent reading prompts")
    ms = t.get("decode_ms")
    o.counter("strata_decode_seconds_total", ms / 1000 if ms is not None else None,
              help_="Time spent generating")

    reqs = [r for r in (d.get("requests") or []) if isinstance(r, dict) and r.get("time")]
    if reqs:
        r = max(reqs, key=lambda r: r["time"])
        o.gauge("strata_last_request_timestamp_seconds", r.get("time"))
        o.gauge("strata_last_request_duration_seconds", r.get("duration_s"))
        o.gauge("strata_last_request_prompt_tokens", r.get("prompt_tokens"))
        o.gauge("strata_last_request_prompt_read_tokens", r.get("prompt_read"))
        o.gauge("strata_last_request_output_tokens", r.get("output_tokens"))
        o.gauge("strata_last_request_decode_tokens_per_second", r.get("decode_tok_s"))
        pm, pr = r.get("prompt_ms"), r.get("prompt_read")
        if pm and pr is not None:
            o.gauge("strata_last_request_prefill_tokens_per_second", pr / (pm / 1000))
        o.gauge("strata_last_request_expert_cache_hit_rate", r.get("hit_rate"),
                help_="Share of expert lookups served from VRAM")
        o.gauge("strata_last_request_pcie_share", r.get("pcie_share"),
                help_="Share of routed experts read over PCIe")
        off, acc = r.get("drafts_offered"), r.get("drafts_accepted")
        if off:
            o.gauge("strata_last_request_draft_accept_ratio", acc / off)
        o.gauge("strata_last_request_finish", 1, {"finish": r.get("finish") or ""})
    return o.text()


def write_atomic(path, text):
    d = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(prefix=".strata.prom.", dir=d)
    try:
        with os.fdopen(fd, "w") as f:
            f.write(text)
        os.chmod(tmp, 0o644)  # mkstemp makes 0600; node-exporter runs as another user
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def main():
    ap = argparse.ArgumentParser(description="Publish Strata's /metrics for the node-exporter textfile collector")
    ap.add_argument("--url", default="http://127.0.0.1:8080/metrics")
    ap.add_argument("--dir", default="/var/lib/node-exporter-textfile")
    ap.add_argument("--interval", type=float, default=5.0)
    ap.add_argument("--once", action="store_true", help="write one file and exit (for testing)")
    a = ap.parse_args()
    path = os.path.join(a.dir, "strata.prom")
    was_up = None
    while True:
        try:
            with urllib.request.urlopen(a.url, timeout=3) as resp:
                d = json.load(resp)
            text = render(d)
            up = True
        except Exception as e:  # server down, loading, or odd JSON: say so and keep polling
            text = "# TYPE strata_up gauge\nstrata_up 0\n"
            up = False
            if was_up is not False:
                print(f"strata not answering: {e}", file=sys.stderr, flush=True)
        if up and was_up is not True:
            print("strata up", file=sys.stderr, flush=True)
        was_up = up
        try:
            write_atomic(path, text)
        except OSError as e:
            print(f"cannot write {path}: {e}", file=sys.stderr, flush=True)
        if a.once:
            return 0 if up else 1
        time.sleep(a.interval)


if __name__ == "__main__":
    sys.exit(main())
