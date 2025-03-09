{ pkgs, ... }: {
  home.packages = [ pkgs.trunk.zed-editor ];
  home.file.".config/zed/settings.json".source = ./settings.jsonc;
  home.file.".config/zed/keymap.json".source = ./keymap.jsonc;
}
