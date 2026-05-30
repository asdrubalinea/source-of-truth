{
  pkgs,
  hostname,
  ...
}: {
  gtk.gtk4.theme = null;

  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

    # Icon theme for Qt/KDE apps (Dolphin, Okular, …). Off by default; without
    # it only `hicolor` is present and Dolphin's toolbar/file icons fall back
    # to blanks. Stylix wires this into both gtk.iconTheme and the qtct config.
    icons = {
      enable = true;
      package = pkgs.kdePackages.breeze-icons;
      dark = "breeze-dark";
      light = "breeze";
    };

    targets = {
      neovim.enable = false;
      alacritty.enable = true;
      kitty.enable = true;
      wezterm.enable = true;
      vscode.enable = false;
      waybar.enable = false;
      # Standalone Home Manager (irene@tempest) has nixosConfig = null, so the
      # qt target does NOT auto-enable. Turn it on explicitly, otherwise Qt
      # apps get no platform theme and Dolphin renders as bare Fusion. Enabling
      # it sets the qtct platform theme + a Kvantum style themed from base16.
      qt.enable = true;
    };

    fonts = {
      sizes = {
        terminal =
          if hostname == "tempest"
          then 16
          else if hostname == "orchid"
          then 22
          else 18;
      };

      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };

      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };

      monospace = {
        package = pkgs.maple-mono.truetype;
        name = "Maple Mono";
      };

      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };
  };
}
