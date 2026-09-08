# The CLI half of the home package set: everything useful over ssh on a machine
# with no display. ./home-packages.nix imports this and adds only the GUI and
# host-hardware sections on top.
#
# It exists so an ocelot (ADR 0013) gets the same shell as tempest from one
# shared file. A new package lands HERE by default and reaches both; making
# something desktop-only is the deliberate act of putting it in
# home-packages.nix instead.
{
  pkgs,
  inputs,
  ...
}: let
  # numtide/llm-agents.nix — AI-agent CLIs. Taken from the flake's own outputs
  # (not overlays.shared-nixpkgs) so they stay built against its pinned nixpkgs
  # and cache.numtide.com actually hits; see flake.nix.
  llm-agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in {
  home.packages = with pkgs; [
    # --- Core system utilities ---
    bc # GNU calculator — `bc -l` for float math inside pipelines
    bubblewrap
    coreutils
    file
    lsof
    moreutils # sponge, ts, vipe, chronic, ifne, errno, pee, vidir
    ntfs3g
    # GNU parallel. moreutils ships its own `parallel`, but nixpkgs gives that
    # one a worse meta.priority precisely so this wins the profile collision.
    parallel
    progress # live throughput/ETA for an already-running cp/dd/tar
    psmisc # pstree, killall, fuser, peekfd
    pv # pipe viewer — progress in the middle of a pipeline

    # --- System monitoring & tracing ---
    btop
    dool # dstat replacement
    fastfetch
    htop
    hyfetch # neofetch fork
    iotop # per-process disk IO (root)
    ltrace # library-call tracer
    lurk # strace, but legible — coloured, filtered syscall output
    nvtopPackages.amd # AMD GPU monitor
    procs # ps with tree view and search
    s-tui # CPU frequency/temperature/power TUI; also drives stress-ng
    strace # syscall tracer
    stress-ng # load generator for thermal / stability testing
    sysstat # iostat, mpstat, pidstat, sar

    # --- File management (CLI only; the GUI file managers stay in
    #     home-packages.nix) ---
    dust # du, sorted, drawn as a tree
    duf # df with a readable table
    dysk # df that reports the actual mount/filesystem layout
    eza
    fd
    ncdu
    nnn # terminal file manager
    sshfs
    trash-cli # trash-put: reversible rm, follows the XDG trash spec
    tree
    yazi

    # --- Archives & compression ---
    # `7zz` — official upstream 7-Zip. Replaces the abandoned p7zip fork (it
    # was stuck on a 2016 upstream) and reads RAR5, so `unar` is now only
    # here for StuffIt and the older RAR variants.
    _7zz
    lz4
    ouch # one verb to (de)compress any archive format
    pigz # parallel gzip
    unar # free RAR/StuffIt/… extractor (`lsar` lists)
    unzip
    xz
    zip
    zstd

    # --- Text, data & code processing ---
    # `sg` (set-group, from shadow) is shadowed by ast-grep's `sg` in this
    # profile; use `ast-grep` for the linter and `/run/wrappers/bin/sg` for the
    # setgid one if it ever comes up.
    ast-grep # structural (AST) code search and rewrite
    bat
    choose # human-readable cut/awk field selection
    csvlens
    datamash # group/sum/mean over columns
    difftastic # `difft` — syntax-aware diff
    glow # render Markdown in the terminal
    hexyl # xxd, but colourised and legible
    jc # convert classic CLI output to JSON — pairs with jq
    jless # pager for JSON/YAML
    jq
    lnav # log navigator: format autodetect, SQL over log files
    miller # `mlr` — awk/sed/cut for CSV/TSV/JSON
    ripgrep
    # rga — ripgrep through PDFs, archives and office docs. Its closure looks
    # huge but is nearly all ffmpeg/pandoc/poppler-utils, already installed here.
    ripgrep-all
    sd # sed for the common case: literal/regex replace without escaping games
    tokei # count code by language
    xxd
    yq-go # jq for YAML/TOML/XML

    # --- Networking & HTTP (postman/proxyman stay in home-packages.nix) ---
    # mtr and wireshark are absent on purpose: programs.mtr and
    # programs.wireshark in hosts/tempest/system/environment.nix install them
    # setcap'd, so they work without sudo.
    aria2 # segmented/multi-connection downloader
    bandwhich # per-process bandwidth (root)
    croc # ad-hoc file transfer between machines, no setup
    curl
    dnsutils # dig, nslookup
    doggo # dig with legible output
    gping # ping, plotted over time
    iftop # per-connection bandwidth (root)
    ipcalc
    iperf3
    nethogs # per-process bandwidth (root)
    nmap
    socat # the everything-relay (also used by rices/ember/compositors/niri/marquee.nix)
    tcpdump # packet capture (root)
    traceroute
    wget
    whois
    xh # HTTPie-style HTTP client, Rust

    # --- Nix tooling ---
    alejandra
    cachix
    comma # `, <cmd>` runs any nixpkgs binary once; reads the nix-index database
    deadnix # find unused Nix bindings
    devbox
    devenv
    manix # search NixOS/HM option and nixpkgs function docs
    nil # Nix LSP
    nix-diff # explain why two derivations differ
    nix-melt # TUI viewer for flake.lock
    nix-output-monitor # `nom` — readable build output; pipe nix builds through it
    nix-tree
    nixd # Nix LSP
    nvd # diff two generations package-by-package
    statix # Nix anti-pattern linter

    # --- Git & version control ---
    delta # syntax-highlighting pager for git diffs
    gh # GitHub CLI
    git-absorb # fold staged hunks into the commits that introduced them
    git-extras # git-summary, git-effort, git-undo, …
    gitleaks # scan history for committed secrets (sops-nix keeps the real ones out)
    gitui
    jujutsu # VCS
    lazygit
    lazyjj # TUI for jujutsu
    tig # ncurses git history browser

    # --- Developer tooling ---
    entr # run a command whenever the files fed to it change
    hyperfine # statistically sound command benchmarking
    just
    onefetch # repo summary (git)
    watchexec # entr, but with glob/ignore rules
    yek # serialize a repo into LLM-ready text
    # httptoolkit

    # --- Languages & runtimes ---
    bun
    jdk21
    lua
    luarocks
    nodejs
    php
    # One shared interpreter on purpose: a second python3.withPackages would
    # collide on bin/python3 in the home profile. pymupdf/markitdown emit
    # LLM-friendly Markdown, pdfplumber pulls tables, pypdf splits/merges.
    #
    # ponytail: pygobject3 (the `gi` module) is unused since the v5 Noctalia
    # migration dropped the Screen Toolkit. Kept only because a bare python3
    # can't import it, so a future GObject script would need this env rebuilt.
    # Safe to drop.
    (python3.withPackages (ps:
      with ps; [
        pygobject3
        pymupdf # fitz — fast render + text/image extraction
        pymupdf4llm # PDF pages -> Markdown tuned for LLM/RAG
        pdfplumber # detailed char/word/table extraction (bundles pdfminer.six)
        pypdf # pure-python split/merge/crop/transform
        markitdown # convert docs (incl. PDF) -> Markdown for LLMs
      ]))
    uv # Python package manager

    # --- Language servers (consumed by helix, zed, vscode) ---
    # Not emacs: desktop/emacs is not imported by any home config today.
    bash-language-server
    clang-tools
    gopls
    harper # Grammar/spell LSP for prose (markdown/typst/org)
    jdt-language-server # Java LSP (Eclipse JDT.LS)
    marksman # Markdown LSP
    phpactor # PHP LSP
    pyright
    ruff
    rust-analyzer
    taplo # TOML LSP + formatter
    texlab # LaTeX LSP
    tinymist # Typst LSP
    typescript-language-server
    vscode-langservers-extracted # HTML/CSS/JSON/ESLint LSPs
    vue-language-server # Vue 3 LSP (Volar)
    yaml-language-server

    # --- Containers & virtualization ---
    distrobox
    dive
    docker-compose

    # --- Shell & terminal (CLI only; the terminal emulators themselves stay in
    #     home-packages.nix — a guest entered over ssh has no display) ---
    asciinema # terminal session recorder
    direnv
    (callPackage ../packages/drift.nix {src = inputs.drift;})
    fzf
    grc
    rlwrap # bolt readline onto REPLs that lack it
    screen
    starship
    tealdeer # `tldr` — worked examples instead of a full man page
    tmux
    # zoxide is enabled as programs.zoxide in misc/fish.nix: the binary is inert
    # without the shell hook that records directory visits.

    # --- AI agent CLIs ---
    claude-code
    llm-agents.codex # OpenAI Codex CLI — llm-agents tracks upstream far closer than nixpkgs does
    llm-agents.opencode
    # OpenCode 2 preview, from npm's `next` channel. Installs as `opencode2`,
    # so it sits alongside the 1.x `opencode` binary rather than replacing it.
    llm-agents.opencode2
    llm-agents.pi
    llm-agents.hermes-agent # Nous Research self-improving agent
    # llm-agents.nix sets doCheck = false, which sidesteps the cargo-test failure
    # that forced the old trunk.rtk pin. It also installs the hooks tree under
    # $out/libexec/rtk/hooks (jq wrapped), which nixpkgs omits.
    llm-agents.rtk
    # antigravity
  ];
}
