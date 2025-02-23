{ pkgs, ... }: {
  fonts = {
    enableDefaultFonts = false;
    fonts = with pkgs; [ cascadia-code fira-code agave ];

    fontconfig = {
      defaultFonts = {
        serif = [ "Operator Mono Medium" ];
        sansSerif = [ "Operator Mono Medium" ];
        monospace = [ "Operator Mono Medium" ];
      };
    };
  };
}
