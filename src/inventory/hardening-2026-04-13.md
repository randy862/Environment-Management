# Hardening Notes - 2026-04-13

This file captures the first stabilization pass after the Proxmox host reboot on April 13, 2026 (America/Chicago).

## What Changed

- Proxmox VM autostart was explicitly enabled for the production VMs.
- Startup ordering was set so dependencies come up in a predictable sequence:
  - `DNS001`: `order=1`, `up=10`
  - `SQL001`: `order=2`, `up=20`
  - `APP001`: `order=3`, `up=30`
  - `WEB001`: `order=4`, `up=40`
- `APP001` runtime services were migrated from `systemd --user` units to system-level units:
  - `hsm-api.service`
  - `hsm-control-api.service`
- The previous user units were disabled.
- `loginctl disable-linger debian` was applied after the migration so app availability no longer depends on a user session.
- `COMMAND001` APT sources were moved from the unauthorized Proxmox enterprise repositories to the no-subscription repositories so security and tooling packages can be installed cleanly.
- `rasdaemon` was installed and enabled on `COMMAND001`.
- A journald drop-in was added on `COMMAND001`:
  - `Storage=persistent`
  - `SystemMaxUse=512M`

## Host Findings

- `COMMAND001` rebooted on April 13, 2026 at approximately `13:13` local time.
- The boot evidence indicates an unclean shutdown:
  - the system journal was replaced after an unclean shutdown
  - `/boot/efi` had its dirty bit set and required fsck cleanup
- The current strongest hardware clue is a recorded machine-check event on the host CPU during the next boot.

## Immediate Priorities

1. Keep the stack boot order deterministic on Proxmox.
2. Add a repeatable health sweep that can be run manually or scheduled from the admin workstation.
3. Install better host-side fault capture on `COMMAND001`.
4. Move `APP001` runtime services from user-level systemd to system-level units.
5. Schedule offline diagnostics for RAM and broader hardware validation.

## Monitoring

- `src/integrations/health/check-platform.ps1` provides a read-only platform sweep.
- It checks:
  - Proxmox host SSH reachability
  - VM running state from `qm list`
  - DNS resolution for expected `school.local` names
  - TCP reachability for DNS and PostgreSQL
  - HTTP health for the web stack
- Run it from the repository root after copying the local config template:

```powershell
Copy-Item src\integrations\config\local.example.psd1 src\integrations\config\local.psd1
powershell -ExecutionPolicy Bypass -File src\integrations\health\check-platform.ps1
powershell -ExecutionPolicy Bypass -File src\integrations\health\check-platform.ps1 -OutputFormat Json
```

## Recommended Scheduling

- Run the platform health check every 5 minutes from the admin workstation.
- Treat a non-zero exit code as a failed probe.
- Persist JSON output to a dated log file and alert from the scheduler wrapper until a better notification path is in place.

## Remaining Work

- Install and enable `rasdaemon` on `COMMAND001`.
- Confirm persistent journaling settings on `COMMAND001`.
- Run additional hardware diagnostics during a maintenance window.
- Review the results of the running extended SMART test on `/dev/sda` after its completion time.
- Schedule an offline memory test for `COMMAND001`.
