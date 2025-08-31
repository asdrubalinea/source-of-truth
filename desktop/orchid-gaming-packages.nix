{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # --- Gaming & Wine ---
    protonup-qt # Proton version manager
    winetricks # Windows dependencies for Wine
    goverlay # MangoHud configuration GUI
    lutris # Gaming launcher with Wine integration
    bottles # Wine bottle manager
    heroic # Epic Games Store launcher
    legendary-gl # Epic Games Store CLI
    # cartridges # GTK4 game launcher (may have libsoup issues)
    # gamehub # Universal game launcher (may have libsoup issues)
    
    # --- Wine Utilities ---
    wineWowPackages.staging # Staging Wine for better compatibility
    
    # --- Game Development & Modding ---
    # openiv # GTA modding tool (not available in nixpkgs)
    
    # --- Performance Monitoring ---
    mangohud # Performance overlay (user config)
    gamemode # Performance optimization (user access)
  ];
}