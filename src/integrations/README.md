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

- `health/check-platform.ps1`
  - Runs a read-only platform sweep across Proxmox, DNS, PostgreSQL, and the web stack.
  - Supports `-OutputFormat Text` and `-OutputFormat Json`.
  - Exits non-zero when one or more checks fail, which makes it suitable for scheduled monitoring.

- `postgres/check-service.ps1`
  - Verifies PostgreSQL service state and `psql` version on `SQL001`.

- `unifi/check-gateway.ps1`
  - Fetches HTTPS headers and the landing page for the UniFi gateway.

- `unifi/check-sites.ps1`
  - Calls the official UniFi `v1/sites` endpoint using the `X-API-KEY` request header.
  - Supports `-OutputFormat Text` and `-OutputFormat Json`.
  - Use `-ShowPlanOnly` to inspect the target endpoint without reading secrets.

- `unifi/get-device-inventory.ps1`
  - Calls the official UniFi device inventory endpoint using the `X-API-KEY` request header.
  - Resolves the configured site selector to a real site ID via `v1/sites` before calling the devices endpoint.
  - Supports `-OutputFormat Text` and `-OutputFormat Json`.
  - Use `-ShowPlanOnly` to inspect the target endpoint and local session file usage.

- `unifi/get-clients.ps1`
  - Calls the official UniFi clients endpoint for the resolved site.
  - Supports `-OutputFormat Text` and `-OutputFormat Json`.

- `unifi/get-interfaces.ps1`
  - Calls the official UniFi interfaces endpoint for the resolved site.
  - Supports `-OutputFormat Text` and `-OutputFormat Json`.

- `unifi/get-site-summary.ps1`
  - Calls the known working UniFi site-level endpoints for devices, clients, and interfaces in one pass.
  - Supports `-OutputFormat Text` and `-OutputFormat Json`.

- `unifi/invoke-request.ps1`
  - Generic UniFi API runner for additional official endpoints from the local UniFi docs.
  - Supports `{siteId}` placeholder replacement via `-ResolveSitePlaceholders`.
  - Supports `-OutputFormat Text` and `-OutputFormat Json`.

## Example Usage

From the repository root in PowerShell:

```powershell
Copy-Item src\integrations\config\local.example.psd1 src\integrations\config\local.psd1
powershell -ExecutionPolicy Bypass -File src\integrations\proxmox\read-vms.ps1
powershell -ExecutionPolicy Bypass -File src\integrations\proxmox\check-host.ps1
powershell -ExecutionPolicy Bypass -File src\integrations\proxmox\read-vms.ps1 -OutputFormat Json
powershell -ExecutionPolicy Bypass -File src\integrations\proxmox\check-host.ps1 -OutputFormat Json
powershell -ExecutionPolicy Bypass -File src\integrations\dns\check-zone.ps1
powershell -ExecutionPolicy Bypass -File src\integrations\health\check-platform.ps1
powershell -ExecutionPolicy Bypass -File src\integrations\postgres\check-service.ps1
powershell -ExecutionPolicy Bypass -File src\integrations\unifi\check-gateway.ps1
powershell -ExecutionPolicy Bypass -File src\integrations\unifi\check-sites.ps1 -ShowPlanOnly
powershell -ExecutionPolicy Bypass -File src\integrations\unifi\get-device-inventory.ps1 -ShowPlanOnly
powershell -ExecutionPolicy Bypass -File src\integrations\unifi\check-sites.ps1 -OutputFormat Json
powershell -ExecutionPolicy Bypass -File src\integrations\unifi\get-device-inventory.ps1 -OutputFormat Json
powershell -ExecutionPolicy Bypass -File src\integrations\unifi\get-clients.ps1 -OutputFormat Json
powershell -ExecutionPolicy Bypass -File src\integrations\unifi\get-interfaces.ps1 -OutputFormat Json
powershell -ExecutionPolicy Bypass -File src\integrations\unifi\get-site-summary.ps1 -OutputFormat Json
powershell -ExecutionPolicy Bypass -File src\integrations\unifi\invoke-request.ps1 -RelativePath 'v1/sites/{siteId}/devices' -ResolveSitePlaceholders -OutputFormat Json
```

These probes are intentionally read-only and should be expanded with structured parsing before any higher-level automation is built on top of them.
