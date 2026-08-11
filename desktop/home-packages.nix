{
  pkgs,
  inputs,
  ...
}: let
  # numtide/llm-agents.nix — AI-agent CLIs. Taken from the flake's own outputs
  # (not overlays.shared-nixpkgs) so they stay built against its pinned nixpkgs
  # and cache.numtide.com actually hits; see flake.nix.
  llm-agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  # Electron cannot infer a password store from the standalone Niri session, so
  # Mailspring otherwise falls back to unencrypted basic_text and refuses to
  # save account credentials. greetd's PAM stack already starts and unlocks
  # GNOME Keyring; tell Electron to use its Secret Service explicitly.
  mailspring-with-keyring = pkgs.mailspring.override {
    commandLineArgs = "--password-store=gnome-libsecret";
  };
in {
  home.packages = with pkgs; [
    # --- Core system utilities ---
    bc # GNU calculator — `bc -l` for float math inside pipelines
    coreutils
    dmidecode # DMI/SMBIOS: board, firmware and DIMM identity
    file
    gnupg
    inxi # one-shot hardware/system summary
    lshw # hardware tree
    lsof
    moreutils # sponge, ts, vipe, chronic, ifne, errno, pee, vidir
    ntfs3g
    nvme-cli # NVMe health/log pages that smartctl doesn't surface
    openssl
    # GNU parallel. moreutils ships its own `parallel`, but nixpkgs gives that
    # one a worse meta.priority precisely so this wins the profile collision.
    parallel
    pciutils
    progress # live throughput/ETA for an already-running cp/dd/tar
    psmisc # pstree, killall, fuser, peekfd
    pv # pipe viewer — progress in the middle of a pipeline
    sbctl # UEFI Secure Boot key management
    smartmontools # smartctl
    trash-cli # trash-put: reversible rm, follows the XDG trash spec
    usbutils
    upower
    bubblewrap
    # opencode # no longer used
    ddcutil

    # --- System info & monitoring ---
    btop
    dool # dstat replacement
    fastfetch
    htop
    hyfetch # neofetch fork
    iotop # per-process disk IO (root)
    lm_sensors
    ltrace # library-call tracer
    nvtopPackages.amd # AMD GPU monitor
    onefetch # repo summary (git)
    powertop
    procs # ps with tree view and search
    s-tui # CPU frequency/temperature/power TUI; also drives stress-ng
    strace # syscall tracer
    stress-ng # load generator for thermal / stability testing
    sysstat # iostat, mpstat, pidstat, sar
    yek

    # --- File management & text processing ---
    # `sg` (set-group, from shadow) is shadowed by ast-grep's `sg` in this
    # profile; use `ast-grep` for the linter and `/run/wrappers/bin/sg` for the
    # setgid one if it ever comes up.
    ast-grep # structural (AST) code search and rewrite
    bat
    cdrtools
    choose # human-readable cut/awk field selection
    csvlens
    czkawka # duplicate finder/cleanup
    datamash # group/sum/mean over columns
    difftastic # `difft` — syntax-aware diff
    dust # du, sorted, drawn as a tree
    duf # df with a readable table
    dysk # df that reports the actual mount/filesystem layout
    eza
    fd
    glow # render Markdown in the terminal
    hexyl # xxd, but colourised and legible
    jc # convert classic CLI output to JSON — pairs with jq
    jless # pager for JSON/YAML
    kdePackages.dolphin # KDE file manager
    jq
    lnav # log navigator: format autodetect, SQL over log files
    lz4
    miller # `mlr` — awk/sed/cut for CSV/TSV/JSON
    ncdu
    nnn # terminal file manager
    ouch # one verb to (de)compress any archive format
    p7zip # 7z
    pigz # parallel gzip
    ripgrep
    # rga — ripgrep through PDFs, archives and office docs. Its closure looks
    # huge but is nearly all ffmpeg/pandoc/poppler-utils, already installed here.
    ripgrep-all
    sd # sed for the common case: literal/regex replace without escaping games
    sshfs
    tokei # count code by language
    unar # free RAR/StuffIt/… extractor (`lsar` lists)
    unzip
    xxd
    xz
    yazi
    yq-go # jq for YAML/TOML/XML
    zip
    zstd
    tree

    # --- Networking & HTTP ---
    # mtr is not here on purpose: hosts/tempest/system/environment.nix enables
    # programs.mtr, which installs it setcap'd so it works without sudo.
    # wireshark is absent for the same reason — programs.wireshark there
    # installs the GUI plus a setcap'd dumpcap for the `wireshark` group.
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
    postman
    socat # the everything-relay (also used by rices/niri/marquee.nix)
    tcpdump # packet capture (root)
    traceroute
    wget
    whois
    xh # HTTPie-style HTTP client, Rust
    yt-dlp

    # --- Backup & sync ---
    borgbackup
    httm # Time-Machine-style TUI to browse/restore ZFS snapshots
    rclone
    restic
    # vorta # Borg GUI

    # --- Nix & developer tooling ---
    alejandra
    cachix
    comma # `, <cmd>` runs any nixpkgs binary once; reads the nix-index database
    deadnix # find unused Nix bindings
    delta # syntax-highlighting pager for git diffs
    devenv
    devbox
    entr # run a command whenever the files fed to it change
    git-absorb # fold staged hunks into the commits that introduced them
    git-extras # git-summary, git-effort, git-undo, …
    gitleaks # scan history for committed secrets (sops-nix keeps the real ones out)
    gitui
    hyperfine # statistically sound command benchmarking
    # httptoolkit
    just
    jujutsu # VCS
    lazygit
    lazyjj # TUI for jujutsu
    lurk # Nix helper (see nixpkgs description)
    manix # search NixOS/HM option and nixpkgs function docs
    nil # Nix LSP
    nix-diff # explain why two derivations differ
    nix-melt # TUI viewer for flake.lock
    nix-output-monitor # `nom` — readable build output; pipe nix builds through it
    nix-tree
    nixd # Nix LSP
    nixpkgs-fmt
    nvd # diff two generations package-by-package
    statix # Nix anti-pattern linter
    tig # ncurses git history browser
    watchexec # entr, but with glob/ignore rules
    gh # GitHub CLI (used by magit/forge)

    inputs.hn-tui-flake.packages.${stdenv.hostPlatform.system}.hackernews-tui # hn TUI

    # --- Languages & runtimes ---
    bun
    jdk21
    lua
    luarocks
    nodejs
    php
    # pygobject3 (the `gi` module) rides on the interpreter for niri's noctalia
    # Screen Toolkit webcam-mirror tool; a bare python3 can't import it. The PDF
    # libs share this one interpreter on purpose — a second python3.withPackages
    # would collide on bin/python3 in the home profile. pymupdf/pymupdf4llm and
    # markitdown emit LLM-friendly Markdown; pdfplumber pulls tables; pypdf does
    # structural split/merge. (camelot dropped — opencv/pandas closure.)
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

    # Language servers (consumed by emacs eglot, helix, etc.)
    pyright
    ruff
    rust-analyzer
    gopls
    clang-tools
    typescript-language-server
    tinymist # Typst LSP
    texlab # LaTeX LSP
    bash-language-server
    marksman # Markdown LSP
    phpactor # PHP LSP
    vscode-langservers-extracted # HTML/CSS/JSON/ESLint LSPs
    vue-language-server # Vue 3 LSP (Volar)
    jdt-language-server # Java LSP (Eclipse JDT.LS)
    harper # Grammar/spell LSP for prose (markdown/typst/org)
    taplo # TOML LSP + formatter
    yaml-language-server

    # --- Containers & virtualization ---
    distrobox
    dive
    docker-compose

    # --- Shell & terminal ---
    alacritty
    asciinema # terminal session recorder
    direnv
    fzf
    ghostty
    (callPackage ../packages/drift.nix {src = inputs.drift;})
    grc
    kitty
    rlwrap # bolt readline onto REPLs that lack it
    screen
    starship
    tealdeer # `tldr` — worked examples instead of a full man page
    tmux
    # zoxide is enabled as programs.zoxide in misc/fish.nix: the binary is inert
    # without the shell hook that records directory visits.
    # Warp lives in desktop/warp.nix (package + declarative settings.toml).
    # alacritty is installed by programs.alacritty (rices/niri/alacritty.nix).

    # --- Desktop integration ---
    appimage-run # run AppImages via Nix
    blueman
    libnotify # notify-send
    # AirPods noise-control/ear-detection/battery. Deliberately NOT pkgs.librepods
    # (that is the superseded Qt build); see packages/librepods.nix.
    (callPackage ../packages/librepods.nix {})
    networkmanagerapplet
    pavucontrol
    seahorse
    solaar
    wl-clipboard

    # --- Browsers ---
    brave
    (callPackage ../packages/brave-origin.nix {})
    firefox
    tor-browser
    google-chrome
    inputs.zen-browser.packages.x86_64-linux.default # Zen Browser

    # --- Communication & productivity ---
    keepassxc
    obsidian
    telegram-desktop
    signal-desktop
    thunderbird
    mailspring-with-keyring
    # vesktop
    zoom-us
    claude-code
    llm-agents.codex # OpenAI Codex CLI; 0.146.0 vs nixpkgs unstable's 0.118.0
    llm-agents.opencode
    # OpenCode 2 preview, from npm's `next` channel. Installs as `opencode2`,
    # so it sits alongside the 1.x `opencode` binary rather than replacing it.
    llm-agents.opencode2
    llm-agents.pi
    llm-agents.hermes-agent # Nous Research self-improving agent
    # rtk 0.44.1, and llm-agents.nix sets doCheck = false, so this sidesteps the
    # cargo-test failure that forced the trunk.rtk pin. It also installs the
    # hooks tree under $out/libexec/rtk/hooks (jq wrapped), which nixpkgs omits.
    llm-agents.rtk
    # antigravity

    # --- Media, graphics & documents ---
    chafa # render images as terminal graphics (kitty/sixel protocols)
    feh
    ffmpeg
    ghostscript
    # gimp3
    imagemagick
    # inkscape
    kdePackages.gwenview # KDE image viewer
    kdePackages.okular
    krita
    libheif
    mpv
    nautilus
    nemo
    obs-studio
    vlc
    onlyoffice-desktopeditors
    xournalpp
    typst
    # (texlive.combine {inherit (texlive) scheme-full;})
    zathura # PDF viewer with SyncTeX inverse search

    # --- PDF tooling (read / extract / OCR / convert / manipulate) ---
    # ghostscript + imagemagick (above) already cover rasterize/convert; these
    # add the text/table/OCR extraction an LLM pipeline needs. The Python libs
    # (pymupdf, pymupdf4llm, pdfplumber, markitdown) live on the python3 env
    # further up, not here. (docling dropped — torch/ML closure.)
    poppler-utils # pdftotext / pdftoppm / pdfimages / pdfinfo / pdffonts / pdftohtml / pdf{detach,separate,unite}
    mupdf # mutool: render, extract text/images, clean, show structure
    qpdf # inspect / repair / decrypt / linearize PDF structure
    pdftk # merge / split / rotate, dump+update metadata, fill forms
    pdfcpu # Go CLI: optimize, encrypt, validate, extract images/text/pages
    pdfgrep # grep across PDF text
    ocrmypdf # add a searchable OCR text layer to scanned PDFs
    tesseract # OCR engine backing ocrmypdf (English only; see tesseract.withLanguages)
    img2pdf # lossless images -> PDF
    pandoc # convert between document formats

    # --- Data & databases ---
    dbeaver-bin
    # litecli # disabled: cli-helpers tests fail in unstable (Pygments ANSI mismatch)
    sqlite
    sqlitebrowser
    tableplus

    # --- Security testing ---
    age # modern file encryption; same recipient format sops-nix already uses
    burpsuite
    pwgen
    qrencode # QR codes from the shell (wifi creds, TOTP URIs, links to phone)
    ssh-audit # audit an sshd's algorithms — pairs with services/ssh-secure.nix
    # caido-desktop

    # --- Games ---
    prismlauncher

    # --- Fun & misc ---
    blahaj
    gay # rainbow output filter
    ponysay
  ];
}
