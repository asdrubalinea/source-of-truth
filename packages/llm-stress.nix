# One-user agent-session stress test for llama-server; the script itself is
# scripts/llm-stress.sh. Like llm-bench, llama-server is not an input: --sweep
# takes it from the unit's own ExecStart.
{
  writeShellApplication,
  coreutils,
  curl,
  findutils,
  gawk,
  gnugrep,
  gnused,
  jq,
  procps,
  systemd,
}:
writeShellApplication {
  name = "llm-stress";
  # sudo is not listed: it has to be the setuid wrapper in /run/wrappers/bin.
  runtimeInputs = [
    coreutils
    curl
    findutils
    gawk
    gnugrep
    gnused
    jq
    procps
    systemd
  ];
  text = builtins.readFile ../scripts/llm-stress.sh;
}
