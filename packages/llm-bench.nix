# Tunes and benchmarks the llama-cpp unit; the script itself is
# scripts/llm-bench.sh. llama-server / llama-bench are deliberately not inputs:
# the script takes them from the unit's own ExecStart, so it always measures
# the build the unit actually runs.
{
  writeShellApplication,
  coreutils,
  curl,
  dmidecode,
  gawk,
  gnugrep,
  gnused,
  jq,
  procps,
  systemd,
  util-linux,
}:
writeShellApplication {
  name = "llm-bench";
  # sudo is not listed: it has to be the setuid wrapper in /run/wrappers/bin.
  runtimeInputs = [
    coreutils
    curl
    dmidecode
    gawk
    gnugrep
    gnused
    jq
    procps
    systemd
    util-linux
  ];
  text = builtins.readFile ../scripts/llm-bench.sh;
}
