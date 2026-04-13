# Discovery Notes - 2026-04-12

This file captures the first read-only discovery pass for the home-lab environment from the local Codex workspace.

## Verified Access

- `APP001` (`192.168.1.200`)
  - SSH login succeeded as `debian`
  - Hostname reported as `APP001`
  - Debian 13 (`trixie`)

- `WEB001` (`192.168.1.210`)
  - SSH login succeeded as `debian`
  - Hostname reported as `WEB001`
  - Debian 13 (`trixie`)

- `SQL001` (`192.168.1.202`)
  - SSH login succeeded as `debian`
  - Hostname reported as `SQL001`
  - Debian 13 (`trixie`)
  - `postgresql` service reported `active`
  - `psql` version `17.9`

- `DNS001` (`192.168.1.203`)
  - SSH login succeeded as `debian`
  - Hostname reported as `DNS001`
  - Debian 13 (`trixie`)
  - `bind9` service reported `active`
  - `school.local` zone found in `/etc/bind/named.conf.local`
  - Zone file observed at `/etc/bind/db.school.local`

## Proxmox Findings

- `COMMAND001` (`192.168.1.110`)
  - SSH port is reachable
  - Host key scan identified `OpenSSH_10.0p2 Debian-7`
  - SSH login now succeeds as `root`
  - Hostname reported as `COMMAND001`
  - Debian 13 (`trixie`) with kernel `6.17.2-1-pve`
  - `pve-manager` version `9.1.1`
  - `qm list` reports VMs `101`, `201`, `202`, `203`, and template `9000`

- `APP001`
  - `proxmoxctl` found at `/home/debian/bin/proxmoxctl`
  - Help output shows commands for VM listing, status, startup, shutdown, cloning, network updates, CPU, RAM, disk resize, and config inspection

## Network Device Findings

- Ubiquiti Cloud Gateway Ultra (`192.168.1.1`)
  - HTTPS interface reachable
  - Landing page identifies `UniFi OS`
  - Embedded manifest identifies model `UDRULT` with short name `UCG Ultra`
  - Follow-up: determine supported local API authentication flow and session handling

- Buffalo NAS LS210D (`192.168.1.50`)
  - HTTP interface reachable with `200 OK`
  - HTTPS probe did not return a successful response
  - SSH key scan on port `22` returned `Connection refused`
  - Follow-up: confirm whether SSH is actually enabled, uses a nonstandard port, or is restricted by configuration

## Recommended Next Actions

1. Decide whether direct `COMMAND001` access or `APP001` plus `proxmoxctl` should be the default Proxmox control path.
2. Extend the existing read-only script layer under `src/integrations/` with:
   - Parsed Proxmox inventory output
   - DNS record inspection for expected A records
   - PostgreSQL connectivity checks beyond service status
   - UniFi OS authentication discovery and session handling
   - NAS reachability and admin-surface discovery
3. Add a non-secret local configuration template for any additional usernames, ports, and host-specific options.
