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

    # ---------- CPU Driver Mode + Governor ----------
    # amd_pstate `active` (amd_pstate_epp driver). In active mode the only
    # pseudo-governors are performance/powersave, and `powersave` is NOT
    # min-pinning — it is EPP-driven dynamic scaling (idle cores drop low, full
    # boost under load). `guided` + schedutil instead pins cores near max at
    # idle by design (schedutil only sets the floor; firmware boosts freely to
    # max-capacity). See docs/framework-control-cpu-frequency.md.
    CPU_DRIVER_OPMODE_ON_BAT = "active";
    CPU_DRIVER_OPMODE_ON_AC = "active";
    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
    CPU_SCALING_GOVERNOR_ON_AC = "powersave";

    # ---------- CPU Energy Policy (EPP) ----------
    # Primary tuning knob in active mode (EPP only exists there — under `guided`
    # these were silently inert). If `power` over-throttles interactive feel on
    # battery, soften to "balance_power".
    # On AC we run `balance_performance`, NOT `performance`. EPP is a bias hint,
    # not a freq floor — but on Strix Point `performance` made even bursty light
    # load (browser JS, compositor, editor) slam cores to ~4.9 GHz and *hold*
    # those clocks/voltage far longer than the work needed, baking Tctl to ~85 °C
    # at idle-ish load while the GPU sat at 0%. `balance_performance` keeps the
    # snappy interactive ramp but lets clocks fall back promptly, so light load
    # runs much cooler/quieter with no perceptible desktop slowdown. Bump back to
    # `performance` only if a sustained CPU workload actually needs it.
    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
    CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";

    # ---------- Turbo Boost Control ----------
    CPU_BOOST_ON_BAT = 0;
    CPU_BOOST_ON_AC = 1;

    # ---------- Platform Profile ----------
    # Sets the firmware's sustained power ceiling (PPT/STAPM). `performance` on
    # AC unlocks sustained all-core throughput; it has no idle effect (the limit
    # only binds under prolonged load) at the cost of more heat/fan under load.
    PLATFORM_PROFILE_ON_BAT = "low-power";
    PLATFORM_PROFILE_ON_AC = "performance";

    # ---------- PCIe ASPM ----------
    PCIE_ASPM_ON_BAT = "powersave";
    PCIE_ASPM_ON_AC = "default";

    # ---------- USB Autosuspend ----------
    # OFF: this firmware's only suspend state is s2idle (S0ix). With autosuspend
    # on, USB devices and the XHCI/USB4 controller power-gate and then fail to
    # re-enumerate on s2idle resume — taking out USB peripherals *and* the
    # external display (DP-over-USB-C rides the same controller). Soft-reboot was
    # the only recovery. This replaces the old `usbcore.autosuspend=-1` kernel
    # workaround (boot.nix); keeping it in TLP avoids duelling tuners.
    USB_AUTOSUSPEND = 0;

    # ---------- Runtime Power Management ----------
    RUNTIME_PM_ON_BAT = "auto";
    RUNTIME_PM_ON_AC = "auto";

    # ---------- WLAN Power Saving ----------
    WIFI_PWR_ON_BAT = 5;
    WIFI_PWR_ON_AC = 1;

    # ---------- Audio Power Saving ----------
    SOUND_POWER_SAVE_ON_BAT = 1;
    SOUND_POWER_SAVE_ON_AC = 1;

    # The MT7925 (RZ717) Wi-Fi must NEVER be PCIe-runtime-suspended on this
    # s2idle box. Once its link/MCU is power-gated it wedges in "driver own
    # failed" (-EIO) and only a full cold power cycle (M.2 rail drop) clears it:
    # FLR, warm reboot, and re-probe with the device forced `on`/D0 all fail.
    #
    # A driver-only denylist is NOT enough, and the reason is subtle: TLP's
    # RUNTIME_PM_DRIVER_DENYLIST only exempts a device whose driver is *currently
    # bound* (05-tlp-func-pm maps each denylisted driver -> the addresses it owns,
    # then skips those). If the mt7925e probe ever fails once, the device sits
    # driverless, TLP no longer recognises it, and runtime-suspends the orphan
    # endpoint — which power-gates it mid-probe on the next attempt and re-wedges
    # it. Circular. That is exactly why the earlier `mt7925e`-only exemption left
    # the device stuck at power/control=auto + suspended with no driver bound.
    #
    # So exempt it BOTH ways:
    #   - RUNTIME_PM_DENYLIST (by PCI address): TLP skips the device even while
    #     unbound (the `deny_address` branch never touches power/control).
    #     c0:00.0 is stable on this fixed topology — native PCIe behind root port
    #     00:02.3 (pcieport), NOT behind the Thunderbolt NHIs (c3:00.5/.6).
    #   - RUNTIME_PM_DRIVER_DENYLIST: keeps it exempt once bound, independent of
    #     bus renumbering. We re-list TLP's intrinsic defaults so overriding this
    #     key doesn't silently drop them — xhci_hcd especially must stay (the
    #     USB4/DP controller, same s2idle re-enum hazard as USB_AUTOSUSPEND above).
    # A udev rule in hardware/framework.nix additionally forces power/control=on
    # by PCI ID (14c3:0717) at enumeration, so the device is pinned on, not merely
    # skipped by TLP. Its parent root port then stays active transitively (runtime
    # PM can't suspend a port with a non-suspended child).
    RUNTIME_PM_DENYLIST = "c0:00.0";
    RUNTIME_PM_DRIVER_DENYLIST = "mei_me nouveau radeon xhci_hcd mt7925e";
  };
}
