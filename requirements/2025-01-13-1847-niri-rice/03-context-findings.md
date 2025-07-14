# Context Findings

## Niri Configuration Requirements

### 1. **Niri Installation Method**
- Use the niri-flake already imported in the main flake.nix
- System module: `programs.niri.enable = true`
- Home-manager module: `programs.niri.settings` for KDL-style configuration
- Binary cache available for faster builds

### 2. **Configuration Format**
- Niri uses KDL (Kindly Defined Language) format
- Can be configured via Nix attribute sets (converted to KDL)
- Alternative: raw KDL strings via `programs.niri.config`

### 3. **Key Mapping Translation**
Hyprland to Niri keybinding translation needed:
- `$mainMod` → `Mod` (Super key)
- Hyprland exec → Niri spawn action
- Different workspace switching syntax
- Different window movement commands

### 4. **Rice Structure to Follow**
```
rices/niri/
├── default.nix       # Imports all modules
├── system.nix        # System-level niri enable
├── niri.nix          # Main niri configuration
├── alacritty.nix     # Terminal (copy from estradiol)
├── waybar/           # Status bar (adapt for niri)
├── tofi.nix          # App launcher (copy from estradiol)
├── stylix.nix        # Rose Pine theme (copy from estradiol)
└── wallpaper/        # Wallpaper with swww (copy from estradiol)
```

### 5. **Files That Need Modification**

**New files to create:**
- `/persist/source-of-truth/rices/niri/default.nix`
- `/persist/source-of-truth/rices/niri/system.nix`
- `/persist/source-of-truth/rices/niri/niri.nix`

**Files to copy and adapt:**
- From estradiol: alacritty.nix, tofi.nix, stylix.nix
- Waybar needs niri-specific workspaces module
- Wallpaper module can be copied as-is

**Host integration points:**
- `/persist/source-of-truth/hosts/tempest.nix` - Add niri rice option
- `/persist/source-of-truth/hosts/orchid.nix` - Add niri rice option
- `/persist/source-of-truth/homes/irene/tempest.nix` - Import niri rice
- `/persist/source-of-truth/homes/irene/orchid.nix` - Import niri rice

### 6. **Technical Constraints**

**Niri-specific features:**
- Column-based layout (not traditional tiling)
- Dynamic workspaces (vertical arrangement)
- Different workspace switching model
- No floating window toggle (different approach)
- Built-in gestures and animations

**Feature differences from Hyprland:**
- No workspace rules by number
- Different monitor configuration syntax
- No window rules by class (uses app-id)
- Different animation system

### 7. **Integration Points**

**Required services:**
- xdg-desktop-portal-gnome (for screencasting)
- Notification daemon (mako recommended)
- Screen locker (swaylock compatible)

**Compatible tools from estradiol:**
- swww (wallpaper daemon)
- waybar (needs niri IPC module)
- tofi (launcher)
- grimblast (screenshot tool)
- playerctl (media controls)
- brightnessctl (backlight)

### 8. **Patterns to Follow**

**From existing rices:**
- Host-specific monitor configuration
- Conditional settings based on hostname
- Stylix for consistent theming
- Modular file organization
- System/home-manager separation

**Niri-specific patterns:**
- Use niri-flake's validation
- Configure via Nix attributes (not raw KDL)
- Leverage niri's built-in features vs external tools

### 9. **Simplified Approach**
Per user request: "keep things simple and make sure that the config is working"
- Skip complex scripts (clamshell handling)
- Focus on core functionality
- Ensure all keybindings work
- Test on both hosts
- Add complexity later if needed