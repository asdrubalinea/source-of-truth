{ lib, ... }:
{
  # Enable TLP for advanced tuning
  services.tlp.enable = lib.mkForce true;

  # Explicitly disable conflicting daemons
  services.power-profiles-daemon.enable = lib.mkForce false;

  # Detailed TLP Configuration
  services.tlp.settings = {
    # --- CPU Settings ---
    # Use the modern scheduler-aware governor
    CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
    CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";

    # Set Energy Performance Preference (EPP) hints
    CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

    # Disable CPU boost on battery for significant power savings
    CPU_BOOST_ON_BAT = 0;
    CPU_BOOST_ON_AC = 1;

    # Replicate PPD's main function by setting the platform profile
    PLATFORM_PROFILE_ON_AC = "performance";
    PLATFORM_PROFILE_ON_BAT = "low-power";

    # --- Device Settings ---
    # Aggressive power saving for PCIe devices. Very effective.
    PCIE_ASPM_ON_BAT = "powersupersave";

    # Power saving for SATA links
    SATA_LINKPWR_ON_BAT = "med_power_with_dipm";

    # Enable runtime power management for devices
    RUNTIME_PM_ON_BAT = "auto";

    # Enable Wi-Fi power saving
    WIFI_PWR_ON_BAT = "on";

    # Enable audio power saving
    SOUND_POWER_SAVE_ON_BAT = 1;
    SOUND_POWER_SAVE_CONTROLLER = "Y";

    # Enable USB autosuspend, but exclude common problematic devices if needed
    USB_AUTOSUSPEND = 1;
    # Example: Exclude a specific mouse or keyboard by USB ID
    # USB_DENYLIST = "1234:5678";

    # --- Battery Care ---
    # Note: Requires correct battery name (e.g., BAT0 or BAT1)
    # Use `upower -d` to find the correct name
    # BIOS charge limit is more reliable
    START_CHARGE_THRESH_BAT0 = 75;
    STOP_CHARGE_THRESH_BAT0 = 80;
  };

  # Enable powertop for diagnostics
  powerManagement.powertop.enable = true;

  # Enable thermal management
  services.thermald.enable = true;

  # Enable TRIM for SSD health
  services.fstrim.enable = true;
}
