{ ... }:

{
  programs.zellij = {
    enable = true;
    settings = {
      show_welcome_banner = false;
      show_startup_tips = false;
      pane_frames = false;
      simplified_ui = true;
    };
  };
}