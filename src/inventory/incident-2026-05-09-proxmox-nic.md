# Proxmox NIC Incident - 2026-05-09

This file captures the Proxmox host crash investigation and remediation pass on May 9, 2026 (America/Chicago).

## Summary

`COMMAND001` crashed or lost host networking again on May 9, 2026. After inspection, the strongest evidence pointed to the onboard Broadcom NetXtreme BCM5762 NIC using the Linux `tg3` driver.

The environment recovered after a package upgrade and reboot. The host is now running a newer Proxmox kernel and firmware package set, and all production VMs came back online.

## Systems Checked

- `COMMAND001` Proxmox host at `192.168.1.110`
- `APP001` VM `101` at `192.168.1.200`
- `WEB001` VM `201` at `192.168.1.210`
- `SQL001` VM `202` at `192.168.1.202`
- `DNS001` VM `203` at `192.168.1.203`
- Debian cloud-init template VM `9000`

## Initial Health Findings

- `COMMAND001` and `APP001` were reachable over SSH after the event.
- All active VMs were running after host recovery:
  - `APP001`
  - `WEB001`
  - `SQL001`
  - `DNS001`
- VM uptimes were only a few minutes, consistent with a recent host reboot.
- `systemctl --failed` reported no failed units on the Proxmox host after recovery.
- Basic storage checks were healthy:
  - SMART overall health for `/dev/sda` passed.
  - Proxmox root filesystem was lightly used.
  - The LVM-thin pool was lightly used.

## Crash Evidence

`last -x` showed multiple prior crash-style boots, including May 9, 2026 and earlier events in April and March.

The relevant May 9 log evidence showed the Broadcom NIC failure pattern:

- `NETDEV WATCHDOG` transmit queue timeout on `nic0`
- `tg3` transmit timeout and reset attempt
- repeated `0xffffffff` register dumps
- repeated `tg3_stop_block timed out` messages
- `tg3_abort_hw timed out, TX_MODE_ENABLE will not clear MAC_TX_MODE=ffffffff`
- `No firmware running`
- `nic0: Link is down`
- `vmbr0` disabled the physical uplink port after `nic0` went down

The same pattern was observed around:

- `2026-05-09 13:17` local time
- `2026-05-09 17:28` local time

This strongly matches the previous April 2026 Broadcom `tg3` lead documented in `hardening-2026-04-13.md`.

## NIC Details Before Remediation

- Device: Broadcom NetXtreme BCM5762 Gigabit Ethernet PCIe
- PCI ID: `14e4:1687`
- Interface: `nic0`
- Driver: `tg3`
- Driver version before upgrade: `6.17.2-1-pve`
- Firmware reported by `ethtool -i`: `5762-v1.29`
- Link when healthy: `1000Mb/s`, full duplex

## Remediation Applied

The host was upgraded through APT and rebooted with user approval.

Commands applied:

```bash
apt update
DEBIAN_FRONTEND=noninteractive apt -y full-upgrade
reboot
```

Key package outcomes:

- `pve-firmware` upgraded from `3.17-2` to `3.18-3`.
- `pve-manager` upgraded from `9.1.1` to `9.1.9`.
- `proxmox-kernel-6.17` upgraded from `6.17.2-1` to `6.17.13-7`.
- `proxmox-kernel-7.0.2-2-pve-signed` was installed.
- `proxmox-default-kernel` was upgraded, and the host booted into `7.0.2-2-pve`.
- `amd64-microcode` was upgraded and will be active after boot.

## Post-Reboot Verification

After reboot, `COMMAND001` reported:

- Kernel: `7.0.2-2-pve`
- Proxmox: `pve-manager 9.1.9`
- Failed systemd units: none
- NIC driver: `tg3`
- NIC driver version: `7.0.2-2-pve`
- NIC firmware: `5762-v1.29`
- NIC link: up at `1000Mb/s`, full duplex

All active VMs were running again:

- `APP001`
- `WEB001`
- `SQL001`
- `DNS001`

Service checks after reboot:

- `WEB001` responded on HTTP with a redirect to HTTPS.
- `SQL001` PostgreSQL accepted connections on port `5432`.
- `WEB001`, `SQL001`, and `DNS001` responded to ping from `APP001`.
- `systemctl --failed` reported no failed units inside the checked VMs.

Current boot logs did not show fresh instances of:

- `NETDEV WATCHDOG`
- `No firmware running`
- `tg3_abort_hw timed out`
- `nic0: Link is down`

## Remaining Observations

The current boot still includes some noisy but non-primary warnings:

- TPM/IMA communication errors
- HP BIOS configuration warning
- ACPI BIOS method errors around `\_SB.ALIB`
- rasdaemon trace availability messages

These did not match the timing or signature of the host-network failure.

`buffalo-backup` was repeatedly reported offline before the NIC event. This may be a symptom of the same network instability, an unavailable NAS/share, or a separate storage reachability issue. It was not the strongest crash cause.

## Recommended Follow-Up

1. Monitor the host journal for recurrence of the `tg3` failure signature.
2. If the same `NETDEV WATCHDOG` and `No firmware running` pattern returns on the newer kernel, treat the onboard Broadcom NIC as unreliable.
3. Prefer replacing or bypassing the onboard NIC with a well-supported Intel-based PCIe NIC.
4. Keep the older `6.17.13-7-pve` kernel installed as a fallback while observing `7.0.2-2-pve`.
5. Continue checking whether `buffalo-backup` reachability problems correlate with NIC resets or are a separate NAS/share issue.
