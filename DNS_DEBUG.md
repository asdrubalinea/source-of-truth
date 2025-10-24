# Tempest DNS Debug Checklist

Use this playbook when DNS stops working, especially after unplugging/reattaching the Framework laptop. All commands assume you have a local shell with no network.

## 1. Capture Context
- Note whether the laptop is on battery or AC, and if any external displays or docks are attached.
- Record the current Wi-Fi AP and whether you recently switched networks.

## 2. Inspect Resolver State
- Show the contents of `/etc/resolv.conf` to confirm who owns DNS:
  ```bash
  cat /etc/resolv.conf
  ```
- If `nameserver 100.100.100.100` or `nameserver 127.0.0.1` appear, Tailscale is still the resolver. Check what systemd thinks:
  ```bash
  resolvectl status
  ```

## 3. Check Tailscale Health
- Confirm Tailscale is connected and advertising DNS:
  ```bash
  sudo tailscale status
  ```
- Collect recent logs:
  ```bash
  sudo journalctl -u tailscaled --since "15 min ago"
  ```
- If `tailscale status` hangs or shows `stopped`, DNS is pointing to a dead stub.

## 4. Verify Wi-Fi Power State
- Inspect the wireless interface:
  ```bash
  iw dev
  nmcli device show wlan0
  ```
  Replace `wlan0` with the interface reported by `iw dev`.
- Look for `GENERAL.STATE` (should be `connected`) and make sure `IP4.DNS` lists real upstream servers when Tailscale is down.

## 5. TLP Power Settings
- TLP may be putting the NIC into deep sleep on battery. Check the recent power events:
  ```bash
  sudo journalctl -u tlp --since "15 min ago"
  ```
- If you see `wifi power save` toggling to `5`, that is the aggressive battery profile.

## 6. NetworkManager Logs
- Confirm whether NetworkManager lost and regained connectivity:
  ```bash
  sudo journalctl -u NetworkManager --since "15 min ago"
  ```
- Pay attention to lines about `device disconnected`, `vpn`, or DNS rewrites.

## 7. Quick Recovery Tricks
- Temporarily bounce Tailscale without rebooting:
  ```bash
  sudo systemctl restart tailscaled
  tailscale up
  ```
- Or hand control to NetworkManager:
  ```bash
  sudo tailscale down
  sudo resolvectl flush-caches
  sudo systemctl restart NetworkManager
  ```

## 8. Report Back
- When you regain connectivity, capture the key findings (battery/AC, Tailscale status, Wi-Fi state, notable log lines) and update the issue so we can adjust TLP or Tailscale settings accordingly.
