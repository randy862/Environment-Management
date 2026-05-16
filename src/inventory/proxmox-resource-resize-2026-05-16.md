# Proxmox Resource Resize - 2026-05-16

This journal entry captures the post-migration CPU and memory allocation change on `COMMAND001` after moving Proxmox to the replacement hardware.

## Summary

After the Proxmox host migration, the production VMs were resized to better use the new hardware while leaving RAM headroom for the host.

The previous host was described as an older i5 system with 12 GB total memory. The replacement host is now online as `COMMAND001.school.local` at `192.168.1.110` with an Intel Core i7-8700, 6 physical cores, 12 threads, and 16 GB installed RAM.

## Host Snapshot

Observed on `COMMAND001` after the resize:

```text
Hostname: COMMAND001
Model: Dell Inc. OptiPlex 7060
CPU: Intel(R) Core(TM) i7-8700 CPU @ 3.20GHz
CPU threads: 12
Cores per socket: 6
Threads per core: 2
Memory reported by OS: 15 GiB
Proxmox: pve-manager/9.1.1
Kernel: 6.17.2-1-pve
```

## Allocation Changes

| VMID | VM | Before | After |
| ---: | --- | ---: | ---: |
| 101 | `APP001` | 4 vCPU / 4 GB RAM | 4 vCPU / 5 GB RAM |
| 201 | `WEB001` | 2 vCPU / 2 GB RAM | 2 vCPU / 3 GB RAM |
| 202 | `SQL001` | 4 vCPU / 4 GB RAM | 6 vCPU / 5 GB RAM |
| 203 | `DNS001` | 1 vCPU / 1 GB RAM | 1 vCPU / 1 GB RAM |

The running production VMs now reserve 13 total vCPU and 14 GB RAM. The stopped Debian cloud-init template remains at 2 vCPU / 2 GB RAM.

## Commands Applied

The VM configuration changes were applied directly on `COMMAND001` through SSH:

```bash
qm set 101 --cores 4 --memory 5120
qm set 201 --cores 2 --memory 3072
qm set 202 --cores 6 --memory 5120
qm set 203 --cores 1 --memory 1024
```

Because the VMs were running, Proxmox initially showed the CPU and memory changes as pending. The affected VMs were then gracefully power-cycled in dependency order.

Shutdown order:

```text
WEB001
APP001
SQL001
```

Startup order:

```text
SQL001
APP001
WEB001
```

`DNS001` was left online because it had no pending change and is a core dependency.

## Verification

Each restarted VM responded to ping after boot:

```text
SQL001: 192.168.1.202 online
APP001: 192.168.1.200 online
WEB001: 192.168.1.210 online
```

Final Proxmox runtime view:

| VMID | VM | Status | CPU | RAM |
| ---: | --- | --- | ---: | ---: |
| 101 | `APP001` | running | 4 vCPU | 5 GB |
| 201 | `WEB001` | running | 2 vCPU | 3 GB |
| 202 | `SQL001` | running | 6 vCPU | 5 GB |
| 203 | `DNS001` | running | 1 vCPU | 1 GB |

`qm pending` showed no remaining `new` entries for VMs `101`, `201`, `202`, or `203`, confirming the allocations are active rather than only staged.

## Follow-Up

- Monitor Proxmox host memory pressure for a few days before adding more RAM to any VM.
- If PostgreSQL load grows, `SQL001` is the most likely next VM to benefit from additional RAM.
- Consider updating the replacement host from Proxmox `9.1.1` / kernel `6.17.2-1-pve` once the migrated environment has been stable.
