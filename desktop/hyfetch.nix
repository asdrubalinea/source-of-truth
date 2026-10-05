{...}: {
  # hyfetch (aliased to neofetch/fetch; installed from ./cli-packages.nix),
  # preset for the lesbian pride flag. Without this it opens its first-run
  # wizard.
  home.file.".config/hyfetch.json" = {
    text = builtins.toJSON {
      preset = "lesbian";
      mode = "rgb";
      auto_detect_light_dark = false;
      light_dark = "dark";
      lightness = null;
      color_align.mode = "horizontal";
      backend = "neofetch";
      args = null;
      distro = null;
      pride_month_disable = false;
      custom_ascii_path = null;
      custom_presets = null;
      palette_glyph = null;
      palette_type = null;
    };
  };
}
