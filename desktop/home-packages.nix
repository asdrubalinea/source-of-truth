# The desktop half of the home package set: GUI applications, desktop
# integration and host-hardware tooling. The CLI half lives in
# ./cli-packages.nix and is imported below, because an ocelot (docs/adr/0013)
# needs it and has no display. The union is what tempest and orchid install, so
# this file's contents plus that file's are exactly the old list.
#
# Where a package belongs: add it to ./cli-packages.nix unless it needs a
# display or a piece of this machine's hardware.
{
  pkgs,
  inputs,
  ...
}: let
  # Electron cannot infer a password store from the standalone Niri session, so
  # Mailspring otherwise falls back to unencrypted basic_text and refuses to
  # save account credentials. greetd's PAM stack already starts and unlocks
  # GNOME Keyring; tell Electron to use its Secret Service explicitly.
  mailspring-with-keyring = pkgs.mailspring.override {
    commandLineArgs = "--password-store=gnome-libsecret";
  };
in {
  imports = [./cli-packages.nix];

  home.packages = with pkgs; [
    # --- Hardware, firmware & power ---
    cdrtools # optical disc authoring/burning
    ddcutil # DDC/CI — external monitor brightness and inputs
    dmidecode # DMI/SMBIOS: board, firmware and DIMM identity
    inxi # one-shot hardware/system summary
    lm_sensors
    lshw # hardware tree
    nvme-cli # NVMe health/log pages that smartctl doesn't surface
    pciutils
    powertop
    sbctl # UEFI Secure Boot key management
    smartmontools # smartctl
    upower
    usbutils

    # --- File management (GUI; the CLI ones are in ./cli-packages.nix) ---
    czkawka # duplicate finder/cleanup
    kdePackages.dolphin # KDE file manager
    kdePackages.konsole # KPart behind Dolphin's F4 terminal panel
    nautilus
    nemo

    # --- Networking & HTTP (GUI; the CLI ones are in ./cli-packages.nix) ---
    postman
    proxyman # HTTP(S) intercepting proxy / inspector
    # yt-dlp comes from ./yt-dlp.nix — the plain package cannot download from
    # YouTube without a PO-token provider behind it.

    # --- Backup & sync ---
    # Host-specific: borg talks to this machine's repo, httm browses this
    # machine's ZFS snapshots.
    borgbackup
    httm # Time-Machine-style TUI to browse/restore ZFS snapshots
    rclone
    restic
    # vorta # Borg GUI

    # --- Shell & terminal (the emulators; the shell tooling is in
    #     ./cli-packages.nix) ---
    alacritty
    ghostty
    kitty
    wezterm
    # Warp lives in desktop/warp.nix (package + declarative settings.toml),
    # imported by homes/orchid.nix. Commented out on tempest.

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
    google-chrome
    tor-browser
    inputs.zen-browser.packages.x86_64-linux.default # Zen Browser
    inputs.helium-browser.packages.x86_64-linux.default # Helium Browser

    # --- Communication & productivity ---
    # IRC. Wayland-native (iced), SASL/SCRAM and TLS out of the box, no
    # scripting layer to configure. Swap for `weechat` if the TUI is wanted.
    halloy
    keepassxc
    mailspring-with-keyring
    # obsidian is installed by ../desktop/obsidian.nix, which also owns its config
    signal-desktop
    telegram-desktop
    zoom-us
    # thunderbird
    # vesktop

    # --- Media & graphics ---
    chafa # render images as terminal graphics (kitty/sixel protocols)
    ffmpeg
    ghostscript
    imagemagick
    kdePackages.gwenview # KDE image viewer
    krita
    libheif
    mpv
    obs-studio
    swayimg # Wayland-native image viewer; replaced feh, which was X11-only
    vlc
    # gimp3
    # inkscape

    # --- Documents & office ---
    kdePackages.okular
    onlyoffice-desktopeditors
    pandoc # convert between document formats
    typst
    xournalpp
    zathura # PDF viewer with SyncTeX inverse search
    # (texlive.combine {inherit (texlive) scheme-full;})

    # --- PDF tooling (read / extract / OCR / convert / manipulate) ---
    # ghostscript + imagemagick (above) already cover rasterize/convert; these
    # add the text/table/OCR extraction an LLM pipeline needs. The Python libs
    # (pymupdf, pymupdf4llm, pdfplumber, markitdown) live on the python3 env in
    # ./cli-packages.nix, not here. (docling dropped — torch/ML closure.)
    img2pdf # lossless images -> PDF
    mupdf # mutool: render, extract text/images, clean, show structure
    ocrmypdf # add a searchable OCR text layer to scanned PDFs
    pdfcpu # Go CLI: optimize, encrypt, validate, extract images/text/pages
    pdfgrep # grep across PDF text
    pdftk # merge / split / rotate, dump+update metadata, fill forms
    poppler-utils # pdftotext / pdftoppm / pdfimages / pdfinfo / pdffonts / pdftohtml / pdf{detach,separate,unite}
    qpdf # inspect / repair / decrypt / linearize PDF structure
    tesseract # OCR engine backing ocrmypdf (English only; see tesseract.withLanguages)

    # --- Data & databases ---
    dbeaver-bin
    sqlite
    sqlitebrowser
    tableplus
    # litecli # disabled: cli-helpers tests fail in unstable (Pygments ANSI mismatch)

    # --- Security & crypto ---
    age # modern file encryption; same recipient format sops-nix already uses
    burpsuite
    gnupg
    openssl
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
