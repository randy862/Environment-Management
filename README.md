# Environment Management

Environment Management is the control-plane repository for Codex-managed access to the home network and lab environment. The goal is to give Codex a structured, safe way to discover, monitor, configure, and automate the full platform over time.

## Purpose

This project is intended to become the single place where we define:

- Environment inventory and topology
- Access patterns for infrastructure and services
- Safe operational workflows for Codex
- Integration code for APIs, SSH-based administration, and service health checks

## Current Environment

### Core Infrastructure

| Component | Role | Address | Notes |
| --- | --- | --- | --- |
| COMMAND001 | Proxmox host | `192.168.1.110` | Physical server |
| APP001 | VM `101` | `192.168.1.200` | SSH access available |
| WEB001 | VM `201` | `192.168.1.210` | SSH access available |
| SQL001 | VM `202` | `192.168.1.202` | SSH access available |
| DNS001 | VM `203` | `192.168.1.203` | SSH access available, `bind9` |
| Buffalo NAS | NAS | `192.168.1.50` | Model `LS210D`, SSH appears enabled |
| Ubiquiti Cloud Gateway Ultra | Network gateway | `192.168.1.1` | Desired API management target |

### Access and Service Notes

- Public-key SSH access is established from this PC to `COMMAND001` and all four VMs.
- `DNS001` runs `bind9`.
- The DNS zone `school.local` contains A records for the Proxmox server and VMs.
- A `proxmoxctl` helper exists on either `COMMAND001` or `APP001`.
- PostgreSQL access exists for the Home-School-Management project.
- Future work should establish Codex-managed access to:
  - Ubiquiti Cloud Gateway Ultra via its API
  - Buffalo NAS `LS210D` via SSH or another safe supported interface

## Project Structure

- `.codex/AGENTS.md` contains operational and safety guidance for Codex and other agents.
- `src/` contains implementation code for integrations, inventory handling, and automation.
- `src/inventory/` stores environment definitions and topology metadata.
- `src/integrations/` is reserved for service-specific connectors such as Proxmox, Ubiquiti, NAS, DNS, and PostgreSQL.
- `src/integrations/config/local.example.psd1` is the non-secret local configuration template for read-only probes.

## Initial Objectives

- Represent the home-lab inventory in code and configuration.
- Verify and document reachable management interfaces.
- Add safe read-only health and discovery operations first.
- Introduce configuration-changing operations only after explicit safeguards are defined.
- Build toward full Codex-assisted monitoring, management, and controlled configuration workflows.

## Suggested Next Steps

1. Capture machine-readable inventory and credentials strategy without committing secrets.
2. Discover where `proxmoxctl` lives and document how it should be invoked.
3. Prototype read-only checks for Proxmox, VMs, DNS, PostgreSQL, Ubiquiti, and the NAS.
4. Add explicit approval gates for any write operations against infrastructure.

## Status

The repository is initialized with documentation and source layout. Implementation code and environment-specific configuration should be added under `src/` as the project evolves.

## Discovery Snapshot

Read-only discovery was run on April 12, 2026 (America/Chicago) with these results:

- SSH access was verified to `APP001`, `WEB001`, `SQL001`, and `DNS001` as user `debian`.
- `COMMAND001` is reachable on SSH and now supports key-based login as `root`.
- `proxmoxctl` was found on `APP001` at `/home/debian/bin/proxmoxctl`.
- `proxmoxctl --help` confirmed available VM management commands including `vms`, `status`, `start`, `shutdown`, `config`, and resource updates.
- Direct Proxmox host access on `COMMAND001` confirmed `pve-manager` version `9.1.1` and the expected VM inventory through `qm list`.
- `DNS001` is running `bind9` and has the `school.local` zone defined in `/etc/bind/named.conf.local` with `/etc/bind/db.school.local`.
- `SQL001` reports PostgreSQL as active and has `psql` version `17.9`.
- The Ubiquiti gateway at `192.168.1.1` is reachable over HTTPS and identifies as UniFi OS model `UCG Ultra`.
- The official UniFi Network API is confirmed reachable with `X-API-KEY` authentication via `/proxy/network/integration/v1/sites`.
- The Buffalo NAS at `192.168.1.50` is reachable over HTTP, HTTPS did not respond successfully, and SSH on port `22` refused connections during this pass.

See `src/inventory/discovery-2026-04-12.md` for the detailed notes and follow-up items.

## Read-Only Probe Layer

The repository now includes a first local probe layer in PowerShell for safe, read-only checks:

- Direct Proxmox host inspection on `COMMAND001`
- Proxmox VM inventory via `APP001` and `/home/debian/bin/proxmoxctl`
- DNS service and zone inspection on `DNS001`
- PostgreSQL service inspection on `SQL001`
- UniFi gateway HTTPS reachability, site discovery, and device inventory via the official API-key flow

To use it:

1. Copy `src/integrations/config/local.example.psd1` to `src/integrations/config/local.psd1`.
2. Adjust usernames, addresses, or paths if the environment changes.
3. Run the probe scripts from `src/integrations/` as documented in `src/integrations/README.md`.

The Proxmox probes now support structured output with `-OutputFormat Json`, which makes them suitable for later Codex-driven automation and inventory comparison workflows.

The UniFi integration now targets the official Network API using the `X-API-KEY` request header and supports machine-readable JSON output for site and device discovery.
It also now includes broader read-only coverage for clients, interfaces, whole-site summaries, and a generic endpoint runner for additional official UniFi API paths.
