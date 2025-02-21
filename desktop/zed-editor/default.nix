{ pkgs, ... }: {
  home.packages = with pkgs; [
    trunk.zed-editor
  ];

  home.file.".config/zed/settings.json".source = ./settings.json;
}
