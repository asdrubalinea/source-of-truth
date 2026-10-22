{
  pkgs,
  lib,
  config,
  ...
}: let
  # wl-kbptr colours are #rrggbbaa; stylix hands out bare rrggbb.
  c = config.lib.stylix.colors;
  rgba = slot: alpha: "#${c.${slot}}${alpha}";
  font = config.stylix.fonts.sansSerif.name;
in
  lib.mkIf config.rices.ember.enable {
    # wl-kbptr: point and click from the keyboard. Overlays the output on a
    # layer-shell surface, takes a label or a few bisecting keystrokes, then
    # drives the cursor through wlr-virtual-pointer — which both compositor
    # layers implement, so it is rice furniture rather than a per-compositor
    # tool. The binds (Mod+K, Mod+Shift+K) live in each layer's own config.
    #
    # nixpkgs builds it with OpenCV, so `floating` mode can detect click
    # targets from a wlr-screencopy frame instead of being fed rectangles.
    #
    # `wl-kbptr-detect` is that mode as a named command, because the mode list
    # needs a comma and mango's bind parser splits on commas.
    home.packages = [
      pkgs.wl-kbptr
      (pkgs.writeShellScriptBin "wl-kbptr-detect" ''
        exec ${pkgs.wl-kbptr}/bin/wl-kbptr \
          -o modes=floating,click -o mode_floating.source=detect "$@"
      '')
    ];

    # The upstream defaults (config.example), recoloured from the palette and
    # set in the rice's face. Accent is base0A, matching tofi's selection.
    xdg.configFile."wl-kbptr/config".text = lib.generators.toINI {} {
      general = {
        modes = "tile,bisect";
        # Escape is not a failure; don't let a spawning bind treat it as one.
        cancellation_status_code = 0;
      };

      mode_tile = {
        label_color = rgba "base05" "dd";
        label_select_color = rgba "base0A" "dd";
        unselectable_bg_color = rgba "base00" "66";
        selectable_bg_color = rgba "base02" "44";
        selectable_border_color = rgba "base09" "cc";
        label_font_family = font;
        label_font_size = "8 50% 100";
        label_symbols = "abcdefghijklmnopqrstuvwxyz";
      };

      mode_floating = {
        source = "stdin";
        label_color = rgba "base05" "dd";
        label_select_color = rgba "base0A" "dd";
        unselectable_bg_color = rgba "base00" "66";
        selectable_bg_color = rgba "base02" "88";
        selectable_border_color = rgba "base09" "cc";
        label_font_family = font;
        # "min proportion max", in logical px, proportion of the detected box's
        # height. Upstream's 12 floor is what nearly every label lands on —
        # detected boxes are a text line or an icon tall — and 12 is unreadable
        # on these panels. A label may now overhang a small box; legibility wins.
        label_font_size = "24 80% 48";
        label_symbols = "abcdefghijklmnopqrstuvwxyz";
      };

      mode_bisect = {
        label_color = rgba "base05" "dd";
        label_font_size = 20;
        label_font_family = font;
        label_padding = 12;
        pointer_size = 20;
        pointer_color = rgba "base08" "dd";
        unselectable_bg_color = rgba "base00" "66";
        even_area_bg_color = rgba "base0B" "44";
        even_area_border_color = rgba "base0B" "88";
        odd_area_bg_color = rgba "base0D" "44";
        odd_area_border_color = rgba "base0D" "88";
        history_border_color = rgba "base03" "99";
      };

      mode_split = {
        pointer_size = 20;
        pointer_color = rgba "base08" "dd";
        bg_color = rgba "base00" "66";
        area_bg_color = rgba "base02" "88";
        vertical_color = rgba "base0D" "cc";
        horizontal_color = rgba "base0B" "cc";
        history_border_color = rgba "base03" "99";
      };

      mode_click.button = "left";
    };
  }
