# Integrations

This directory is reserved for service-specific integrations used by Codex to inspect and manage the home lab.

Planned integration areas:

- `proxmox/` for VM and host operations, likely using `proxmoxctl` on `APP001`
  - Direct host inspection on `COMMAND001` is also available over SSH as `root`
- `dns/` for `bind9` and `school.local` inspection workflows
- `postgres/` for database service and connectivity checks
- `unifi/` for Cloud Gateway Ultra API access
- `nas/` for Buffalo LS210D discovery and administration support

The preferred implementation order is read-only discovery first, then controlled write operations after safeguards and approval gates are in place.

## Current Read-Only Probes

- `config/local.example.psd1`
  - Copy to `config/local.psd1` and adjust host details as needed.
  - Keep secrets and tokens out of version control.

- `proxmox/read-vms.ps1`
  - Runs `/home/debian/bin/proxmoxctl vms` on `APP001` over SSH.
  - Supports `-OutputFormat Text` and `-OutputFormat Json`.

- `proxmox/check-host.ps1`
  - Runs `hostnamectl`, `pveversion`, and `qm list` directly on `COMMAND001` over SSH.
  - Supports `-OutputFormat Text` and `-OutputFormat Json`.

- `dns/check-zone.ps1`
  - Verifies `bind9` is active and searches for a zone reference on `DNS001`.

- `postgres/check-service.ps1`
  - Verifies PostgreSQL service state and `psql` version on `SQL001`.

- `unifi/check-gateway.ps1`
  - Fetches HTTPS headers and the landing page for the UniFi gateway.

## Example Usage

From the repository root in PowerShell:

```powershell
Copy-Item src\integrations\config\local.example.psd1 src\integrations\config\local.psd1
powershell -ExecutionPolicy Bypass -File src\integrations\proxmox\read-vms.ps1
powershell -ExecutionPolicy Bypass -File src\integrations\proxmox\check-host.ps1
powershell -ExecutionPolicy Bypass -File src\integrations\proxmox\read-vms.ps1 -OutputFormat Json
powershell -ExecutionPolicy Bypass -File src\integrations\proxmox\check-host.ps1 -OutputFormat Json
powershell -ExecutionPolicy Bypass -File src\integrations\dns\check-zone.ps1
powershell -ExecutionPolicy Bypass -File src\integrations\postgres\check-service.ps1
powershell -ExecutionPolicy Bypass -File src\integrations\unifi\check-gateway.ps1
```

These probes are intentionally read-only and should be expanded with structured parsing before any higher-level automation is built on top of them.
