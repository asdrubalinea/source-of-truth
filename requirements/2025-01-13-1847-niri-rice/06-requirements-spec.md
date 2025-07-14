# Requirements Specification: Niri Rice

## Problem Statement
Create a new rice configuration that uses Niri as the window manager instead of Hyprland, while maintaining the same aesthetic, keybindings, and functionality as the existing estradiol rice. This allows users to choose between different window managers while keeping a consistent user experience.

## Solution Overview
Develop a new "niri" rice that:
- Replicates all estradiol rice keybindings and features using Niri
- Maintains the Rose Pine theme and visual consistency
- Works on both orchid (desktop) and tempest (laptop) hosts
- Can be selected via the existing rice option system
- Focuses on working configuration over complex features initially

## Functional Requirements

### 1. Rice Selection
- Add "niri" as a valid option for the `rice` setting in host configurations
- Hosts can select niri rice with `rice = "niri";`
- Both orchid and tempest should support the niri rice

### 2. Keybindings (Must Match Estradiol)
All keybindings from estradiol must work in niri:
- `Super + Return`: Open terminal (alacritty)
- `Super + Space`: Open launcher (tofi)
- `Super + Q`: Close active window
- `Super + Shift + Space`: Toggle floating (adapt for niri)
- `Super + F`: Fullscreen window
- `Super + 1-0`: Switch to workspace 1-10
- `Super + Shift + 1-0`: Move window to workspace 1-10
- `Super + Arrow keys`: Move focus between windows
- `Super + Shift + Arrow keys`: Move windows
- `Super + Shift + B`: Open browser (zen-browser)
- `Super + Shift + S`: Screenshot area (use niri's built-in)
- `Super + Shift + D`: Screenshot area to clipboard
- Media keys: Volume up/down/mute, brightness up/down
- Function keys: Audio/brightness control

### 3. Visual Consistency
- Use Rose Pine theme via Stylix
- Same fonts: Maple Mono (monospace), DejaVu Sans/Serif
- Same font sizes: 16pt on tempest, 20pt on orchid
- Border size: 2px with Rose Pine colors
- Gaps: 3px inner, 5px outer (adapt to niri's gap system)
- Corner radius: 5px
- Blur effects where supported

### 4. Monitor Configuration
- **Orchid**: Dual monitor setup
  - Primary: 3440x1440@75Hz
  - Secondary: 2560x1440@60Hz
- **Tempest**: Single display
  - eDP: 2880x1920@120Hz scaled by 2

### 5. Applications
- Terminal: Alacritty (copy existing config)
- Launcher: Tofi (copy existing config)
- Status bar: Waybar with niri IPC module
- Wallpaper: swww with same images
- Browser: zen-browser
- Screenshots: Use niri's built-in UI

### 6. Workspace Behavior
- Maintain workspaces 1-10 despite niri's dynamic model
- Configure static workspaces if possible
- Preserve workspace switching keybindings

### 7. Performance
- Animations enabled on orchid
- Animations disabled on tempest
- Maintain host-specific optimizations

## Technical Requirements

### 1. File Structure
Create the following structure:
```
rices/niri/
├── default.nix       # Import all modules
├── system.nix        # Enable niri, install fonts
├── niri.nix          # Main niri configuration
├── alacritty.nix     # Terminal (copy from estradiol)
├── waybar/           # Status bar (adapt for niri)
│   ├── default.nix
│   ├── config.jsonc
│   └── style.css
├── tofi.nix          # Launcher (copy from estradiol)
├── stylix.nix        # Theme (copy from estradiol)
└── wallpaper/        # Wallpaper (copy from estradiol)
    ├── default.nix
    └── *.jpg/jpeg
```

### 2. System Integration
- Use niri-flake already imported in main flake.nix
- System module: `programs.niri.enable = true`
- Configure via home-manager: `programs.niri.settings`

### 3. Configuration Approach
- Use Nix attribute sets (not raw KDL)
- Leverage niri-flake's validation
- Host-specific conditionals for monitors/performance

### 4. Module Updates
- Update host files to recognize "niri" rice option
- Update home configurations to import niri rice
- Ensure proper imports chain

## Implementation Hints

### 1. Keybinding Translation
```nix
binds = with config.lib.niri.actions; {
  "Mod+Return".action = spawn "alacritty";
  "Mod+Space".action = spawn "tofi-drun | tofi --config /path/to/config";
  "Mod+Q".action = close-window;
  # ... etc
};
```

### 2. Workspace Configuration
```nix
prefer-no-csd = true;
workspaces = {
  # Configure 10 static workspaces
};
```

### 3. Monitor Setup
```nix
outputs = {
  "DP-1" = {
    mode = { width = 3440; height = 1440; refresh = 75.0; };
  };
  "DP-2" = {
    mode = { width = 2560; height = 1440; refresh = 60.0; };
    position = { x = 3440; y = 0; };
  };
};
```

### 4. Host Detection
```nix
{ config, hostname, ... }:
let
  isOrchid = hostname == "orchid";
  isTempest = hostname == "tempest";
in {
  # ... conditional configuration
}
```

## Acceptance Criteria

1. ✓ Niri rice can be selected in host configuration
2. ✓ All estradiol keybindings work in niri
3. ✓ Rose Pine theme applied consistently
4. ✓ Works on both orchid and tempest
5. ✓ Waybar shows niri workspaces
6. ✓ Screenshots work with niri's built-in UI
7. ✓ Terminal, launcher, and browser launch correctly
8. ✓ Host-specific monitor configurations applied
9. ✓ Performance optimizations per host
10. ✓ System rebuilds without errors

## Assumptions
- Niri's built-in screenshot UI is sufficient (no grimblast needed)
- Static workspace configuration is possible in niri
- Niri IPC module for waybar is available
- Floating window behavior differs but is acceptable
- Complex scripts (clamshell) not needed initially
- Binary cache speeds up niri builds