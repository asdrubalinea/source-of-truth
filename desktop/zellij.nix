{ ... }:

{
  programs.zellij = {
    enable = true;
    settings = {
      show_welcome_banner = false;
      pane_frames = false;
      simplified_ui = true;
    };
  };
}