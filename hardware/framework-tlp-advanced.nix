{lib, ...}: {
  services = {
    # mkForce on both: hardware/framework.nix (which imports this) sets the same
    # two at normal priority, and TLP and power-profiles-daemon are mutually
    # exclusive — so state the winner here, where the TLP settings live.
    tlp.enable = lib.mkForce true;
    power-profiles-daemon.enable = lib.mkForce false;

    # Also set, identically, in hardware/framework.nix — unintentional
    # duplication; one of the two should own them.
    thermald.enable = true;
    fstrim.enable = true;
  };

  powerManagement.powertop.enable = false;

  services.tlp.settings = {
    TLP_ENABLE = 1;

    # `active` (amd_pstate_epp). Its `powersave` is not min-pinning but
    # EPP-driven dynamic scaling; `guided` + schedutil instead pins cores near
    # max at idle by design. See docs/framework-control-cpu-frequency.md.
    CPU_DRIVER_OPMODE_ON_BAT = "active";
    CPU_DRIVER_OPMODE_ON_AC = "active";
    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
    CPU_SCALING_GOVERNOR_ON_AC = "powersave";

    # The primary knob — EPP exists only in active mode (under `guided` these
    # were silently inert). Soften battery to "balance_power" if `power`
    # over-throttles interactive feel.
    #
    # AC is deliberately balance_performance, NOT performance: on Strix Point
    # `performance` made bursty light load slam cores to ~4.9 GHz and hold them,
    # baking Tctl to ~85 °C with the GPU at 0%. Bump it back only for a
    # genuinely sustained CPU workload.
    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
    CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";

    CPU_BOOST_ON_BAT = 0;
    CPU_BOOST_ON_AC = 1;

    # The firmware's sustained power ceiling (PPT/STAPM). `balanced` rather than
    # `performance` on AC: for this machine's actual duty cycle (bursty light
    # load, GPU idle) that headroom went almost entirely into heat. Pairs with
    # EPP=balance_performance above.
    PLATFORM_PROFILE_ON_BAT = "low-power";
    PLATFORM_PROFILE_ON_AC = "balanced";

    PCIE_ASPM_ON_BAT = "powersave";
    PCIE_ASPM_ON_AC = "default";

    # OFF: the only suspend state here is s2idle, and with autosuspend on, USB
    # devices and the XHCI/USB4 controller power-gate and then fail to
    # re-enumerate on resume — taking out peripherals AND the external display,
    # which rides the same controller. Soft-reboot was the only recovery. This
    # replaces the old `usbcore.autosuspend=-1` kernel param.
    USB_AUTOSUSPEND = 0;

    RUNTIME_PM_ON_BAT = "auto";
    RUNTIME_PM_ON_AC = "auto";

    WIFI_PWR_ON_BAT = 5;
    WIFI_PWR_ON_AC = 1;

    SOUND_POWER_SAVE_ON_BAT = 1;
    SOUND_POWER_SAVE_ON_AC = 1;

    # The MT7925 Wi-Fi must NEVER be PCIe-runtime-suspended on this s2idle box:
    # once power-gated it wedges in "driver own failed" (-EIO) and only a cold
    # power cycle clears it — FLR, warm reboot and forcing D0 all fail.
    #
    # Exempting by driver alone is NOT enough, and circularly so:
    # RUNTIME_PM_DRIVER_DENYLIST only covers a device whose driver is currently
    # bound, so one failed mt7925e probe leaves the device driverless,
    # unrecognised, runtime-suspended as an orphan — and re-wedged mid-probe on
    # the next attempt. Hence both keys:
    #   - RUNTIME_PM_DENYLIST by PCI address, which TLP honours even while
    #     unbound. c0:00.0 is stable here — native PCIe behind root port
    #     00:02.3, not behind the Thunderbolt NHIs.
    #   - RUNTIME_PM_DRIVER_DENYLIST to keep it exempt once bound, independent
    #     of bus renumbering. TLP's intrinsic defaults are re-listed so
    #     overriding the key doesn't silently drop them — xhci_hcd especially,
    #     same s2idle re-enumeration hazard as USB_AUTOSUSPEND above.
    # hardware/framework.nix additionally pins power/control=on by PCI ID at
    # enumeration, so the device is held on rather than merely skipped; its
    # parent root port then stays active transitively.
    RUNTIME_PM_DENYLIST = "c0:00.0";
    RUNTIME_PM_DRIVER_DENYLIST = "mei_me nouveau radeon xhci_hcd mt7925e";
  };
}
