{ config, lib, ... }:

{
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    keyMode = "vi";
    mouse = true;
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 10000;

    extraConfig = ''
      # Enable 256 colors and true color support
      set -ga terminal-overrides ",*256col*:Tc"
      
      # Set pane base index to 1
      setw -g pane-base-index 1

      # Zellij-like keybindings

      # Pane management (Ctrl+p equivalent)
      # Split panes like zellij
      bind-key -n C-p switch-client -T pane_mode
      bind-key -T pane_mode n split-window -c "#{pane_current_path}"
      bind-key -T pane_mode r split-window -h -c "#{pane_current_path}"
      bind-key -T pane_mode d split-window -v -c "#{pane_current_path}"
      bind-key -T pane_mode x kill-pane
      bind-key -T pane_mode f resize-pane -Z
      bind-key -T pane_mode h select-pane -L
      bind-key -T pane_mode j select-pane -D
      bind-key -T pane_mode k select-pane -U
      bind-key -T pane_mode l select-pane -R
      bind-key -T pane_mode Left select-pane -L
      bind-key -T pane_mode Down select-pane -D
      bind-key -T pane_mode Up select-pane -U
      bind-key -T pane_mode Right select-pane -R
      bind-key -T pane_mode Escape switch-client -T root

      # Tab/Window management (Ctrl+t equivalent)
      bind-key -n C-t switch-client -T tab_mode
      bind-key -T tab_mode n new-window -c "#{pane_current_path}"
      bind-key -T tab_mode x kill-window
      bind-key -T tab_mode r command-prompt -I "#W" "rename-window '%%'"
      bind-key -T tab_mode h previous-window
      bind-key -T tab_mode l next-window
      bind-key -T tab_mode j previous-window
      bind-key -T tab_mode k next-window
      bind-key -T tab_mode Left previous-window
      bind-key -T tab_mode Right next-window
      bind-key -T tab_mode 1 select-window -t :=1
      bind-key -T tab_mode 2 select-window -t :=2
      bind-key -T tab_mode 3 select-window -t :=3
      bind-key -T tab_mode 4 select-window -t :=4
      bind-key -T tab_mode 5 select-window -t :=5
      bind-key -T tab_mode 6 select-window -t :=6
      bind-key -T tab_mode 7 select-window -t :=7
      bind-key -T tab_mode 8 select-window -t :=8
      bind-key -T tab_mode 9 select-window -t :=9
      bind-key -T tab_mode Escape switch-client -T root

      # Resize mode (Ctrl+n equivalent)
      bind-key -n C-n switch-client -T resize_mode
      bind-key -T resize_mode h resize-pane -L 2
      bind-key -T resize_mode j resize-pane -D 2
      bind-key -T resize_mode k resize-pane -U 2
      bind-key -T resize_mode l resize-pane -R 2
      bind-key -T resize_mode Left resize-pane -L 2
      bind-key -T resize_mode Down resize-pane -D 2
      bind-key -T resize_mode Up resize-pane -U 2
      bind-key -T resize_mode Right resize-pane -R 2
      bind-key -T resize_mode + resize-pane -U 2
      bind-key -T resize_mode - resize-pane -D 2
      bind-key -T resize_mode = select-layout even-horizontal
      bind-key -T resize_mode Escape switch-client -T root

      # Scroll mode (Ctrl+s equivalent)
      bind-key -n C-s copy-mode
      bind-key -T copy-mode-vi j send-keys -X cursor-down
      bind-key -T copy-mode-vi k send-keys -X cursor-up
      bind-key -T copy-mode-vi h send-keys -X cursor-left
      bind-key -T copy-mode-vi l send-keys -X cursor-right
      bind-key -T copy-mode-vi d send-keys -X halfpage-down
      bind-key -T copy-mode-vi u send-keys -X halfpage-up
      bind-key -T copy-mode-vi C-f send-keys -X page-down
      bind-key -T copy-mode-vi C-b send-keys -X page-up
      bind-key -T copy-mode-vi / command-prompt -i -I "#{pane_search_string}" -p "(search down)" "send -X search-forward-incremental \"%%%\""
      bind-key -T copy-mode-vi ? command-prompt -i -I "#{pane_search_string}" -p "(search up)" "send -X search-backward-incremental \"%%%\""
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
      bind-key -T copy-mode-vi Escape send-keys -X cancel

      # Session mode (Ctrl+o equivalent)
      bind-key -n C-o switch-client -T session_mode
      bind-key -T session_mode d detach-client
      bind-key -T session_mode w choose-session
      bind-key -T session_mode Escape switch-client -T root

      # Alt shortcuts (direct navigation like zellij)
      bind-key -n M-h select-pane -L
      bind-key -n M-j select-pane -D
      bind-key -n M-k select-pane -U
      bind-key -n M-l select-pane -R
      bind-key -n M-Left select-pane -L
      bind-key -n M-Down select-pane -D
      bind-key -n M-Up select-pane -U
      bind-key -n M-Right select-pane -R
      bind-key -n M-n split-window -c "#{pane_current_path}"
      bind-key -n M-f resize-pane -Z
      bind-key -n M-i swap-window -t -1\; select-window -t -1
      bind-key -n M-o swap-window -t +1\; select-window -t +1
      bind-key -n M-+ resize-pane -U 2
      bind-key -n M-- resize-pane -D 2
      bind-key -n M-[ previous-layout
      bind-key -n M-] next-layout

      # Status bar configuration (minimal like zellij)
      set -g status on
      set -g status-position bottom
      set -g status-style 'bg=colour235 fg=colour137'
      set -g status-left ""
      set -g status-right '#[fg=colour233,bg=colour241,bold] %d/%m #[fg=colour233,bg=colour245,bold] %H:%M:%S '
      set -g status-right-length 50
      set -g status-left-length 20

      setw -g window-status-current-style 'fg=colour1 bg=colour238 bold'
      setw -g window-status-current-format ' #I#[fg=colour249]:#[fg=colour255]#W#[fg=colour249]#F '

      setw -g window-status-style 'fg=colour9 bg=colour236'
      setw -g window-status-format ' #I#[fg=colour237]:#[fg=colour250]#W#[fg=colour244]#F '

      # Pane borders
      set -g pane-border-style 'fg=colour238 bg=colour235'
      set -g pane-active-border-style 'bg=colour235 fg=colour51'

      # Copy to system clipboard (Linux)
      bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "wl-copy"
      bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "wl-copy"

      # Reload config
      bind-key r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"
    '';
  };
}
