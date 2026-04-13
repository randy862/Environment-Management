# AGENTS.md

This repository manages real home-lab infrastructure. Any agent working here must optimize for safety, auditability, and small reversible changes.

## Mission

- Help Codex monitor, manage, and configure the home network and lab platform.
- Treat infrastructure access as high-impact even when commands appear routine.
- Build reliable operational tooling without storing secrets in the repository.

## Core Rules

- Read first, change second.
- Prefer read-only verification before proposing or applying configuration changes.
- Never make destructive or service-affecting changes without explicit user intent.
- Keep every change focused, documented, and easy to review.
- Do not commit credentials, tokens, private keys, or connection secrets.

## Safety Requirements

- For infrastructure tasks, start with discovery and health checks whenever possible.
- Use the narrowest possible target scope for commands and automation.
- Confirm intent before restarting services, changing network configuration, altering DNS, resizing storage, or modifying virtual machine state.
- Preserve existing user changes and live environment state unless the requested task clearly requires modification.
- Record assumptions when device behavior, ownership, or command location is uncertain.

## Repository Expectations

- Put implementation code in `src/`.
- Put inventory and topology definitions in `src/inventory/`.
- Put service connectors and API clients in `src/integrations/`.
- Keep documentation current when new components, access methods, or workflows are added.
- Store only templates, examples, and non-secret defaults in version control.

## Operational Approach

- Prefer idempotent scripts and clear logging.
- Separate read-only operations from mutating operations in code structure.
- Add validation and dry-run behavior before introducing write-capable automation.
- Surface risks clearly when working with Proxmox, DNS, gateways, databases, or storage systems.

## Current Environment Context

- Proxmox host: `COMMAND001` at `192.168.1.110`
- VMs:
  - `APP001` / VMID `101` / `192.168.1.200`
  - `WEB001` / VMID `201` / `192.168.1.210`
  - `SQL001` / VMID `202` / `192.168.1.202`
  - `DNS001` / VMID `203` / `192.168.1.203`
- DNS zone: `school.local` on `DNS001` via `bind9`
- NAS: Buffalo `LS210D` at `192.168.1.50`
- Gateway: Ubiquiti Cloud Gateway Ultra at `192.168.1.1`

## Preferred Workflow

1. Inspect inventory and existing documentation.
2. Verify connectivity with the safest available read-only command.
3. Identify the exact target component and blast radius.
4. Make the smallest change that satisfies the task.
5. Validate the outcome and report any gaps.
