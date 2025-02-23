{ pkgs, ... }: {
  home.packages = with pkgs; [ zed-editor ];
  home.file.".config/zed/settings.json".source = ./settings.jsonc;
}
