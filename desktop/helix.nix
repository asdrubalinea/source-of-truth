{ ... }:

{
  programs.helix = {
    enable = true;
    
    settings = {
      # theme = "ayu_dark";
      
      editor = {
        line-number = "relative";
        bufferline = "always";
        cursorline = true;
        
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        
        file-picker = {
          hidden = false;
        };
        
        soft-wrap = {
          enable = true;
        };
        
        statusline = {
          left = ["mode" "spinner"];
          center = ["file-name"];
          right = ["diagnostics" "selections" "position" "file-encoding" "file-line-ending" "file-type"];
          separator = "│";
          mode.normal = "NORMAL";
          mode.insert = "INSERT";
          mode.select = "SELECT";
        };
      };
    };
    
    languages = {
      language-server.rust-analyzer = {
        command = "rust-analyzer";
        config = {
          check.command = "clippy";
          cargo.features = "all";
        };
      };
      
      language = [{
        name = "rust";
        language-servers = ["rust-analyzer"];
      }];
    };
  };
}
