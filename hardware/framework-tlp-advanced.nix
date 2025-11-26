{ lib, ... }:
{
  services = {
    # Enable TLP for advanced tuning
    tlp.enable = lib.mkForce true;

    # Explicitly disable conflicting daemons
    power-profiles-daemon.enable = lib.mkForce false;

    # Enable thermal management
    thermald.enable = true;

    # Enable TRIM for SSD health
    fstrim.enable = true;
  };

  powerManagement.powertop.enable = false;

  # Detailed TLP Configuration
  services.tlp.settings = {
    # ---------- General Settings ----------
    TLP_ENABLE = 1;

    # ---------- CPU Governor ----------
    CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";
    CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
    CPU_DRIVER_OPMODE_ON_BAT = "guided";
    CPU_DRIVER_OPMODE_ON_AC = "guided";

    # ---------- CPU Energy Policy (EPP) ----------
    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
    CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";

    # ---------- Turbo Boost Control ----------
    CPU_BOOST_ON_BAT = 0;
    CPU_BOOST_ON_AC = 1;

    # ---------- Platform Profile ----------
    PLATFORM_PROFILE_ON_BAT = "low-power";
    PLATFORM_PROFILE_ON_AC = "balanced";

    # ---------- PCIe ASPM ----------
    PCIE_ASPM_ON_BAT = "powersave";
    PCIE_ASPM_ON_AC = "default";

    # ---------- USB Autosuspend ----------
    USB_AUTOSUSPEND = 1;

    # ---------- Runtime Power Management ----------
    RUNTIME_PM_ON_BAT = "auto";
    RUNTIME_PM_ON_AC = "auto";

    # ---------- WLAN Power Saving ----------
    WIFI_PWR_ON_BAT = 5;
    WIFI_PWR_ON_AC = 1;

    # ---------- Audio Power Saving ----------
    SOUND_POWER_SAVE_ON_BAT = 1;
    SOUND_POWER_SAVE_ON_AC = 1;

    # Enable runtime power management for GPU
    RUNTIME_PM_DRIVER_BLACKLIST = "";
  };
}
