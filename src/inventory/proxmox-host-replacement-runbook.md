# Proxmox Host Replacement Runbook

This runbook captures the planned replacement of the current `COMMAND001` Proxmox host with newer hardware. The desired final state is that the new hardware becomes `COMMAND001` at `192.168.1.110`, the old host is retired, the VMs are restored from Buffalo NAS backups, SSH access is restored, and NAS backup storage is attached to the new Proxmox install.

## Current State

| System | Role | IP |
| --- | --- | --- |
| `COMMAND001` | Old Proxmox host | `192.168.1.110` |
| `APP001` | VM `101` | `192.168.1.200` |
| `WEB001` | VM `201` | `192.168.1.210` |
| `SQL001` | VM `202` | `192.168.1.202` |
| `DNS001` | VM `203` | `192.168.1.203` |
| `debian-13-cloudinit-template` | Template `9000` | none |
| Buffalo NAS | Backup storage | `192.168.1.50` |

## Target State

| System | Role | IP |
| --- | --- | --- |
| `COMMAND001` | New Proxmox host on replacement hardware | `192.168.1.110` |
| `APP001` | Restored VM `101` | `192.168.1.200` |
| `WEB001` | Restored VM `201` | `192.168.1.210` |
| `SQL001` | Restored VM `202` | `192.168.1.202` |
| `DNS001` | Restored VM `203` | `192.168.1.203` |
| Buffalo NAS | Proxmox backup storage | `192.168.1.50` |

## Important Rules

- Do not run the old and new Proxmox hosts on `192.168.1.110` at the same time.
- Do not start restored VMs on the new host while the old VMs are still running.
- Prefer backup and restore from the NAS over temporary clustering or live migration because the old host has NIC instability.
- If the new host is temporarily installed as another hostname or IP for staging, rename it and move it to `192.168.1.110` while it is still an empty Proxmox node, before restoring VMs.
- Keep the old host powered off and disconnected during final cutover until the new host and restored VMs are validated.

## Phase 1: Preflight On Old Host

Run these on the old `COMMAND001` before the maintenance window:

```bash
pveversion
qm list
pvesm status
cat /etc/network/interfaces
cat /etc/pve/storage.cfg
```

Confirm VM backups are present on the NAS-backed storage:

```bash
find /mnt/pve -path '*/dump/vzdump-qemu-*' -type f -ls
```

Confirm backups exist for:

```text
101 APP001
201 WEB001
202 SQL001
203 DNS001
9000 debian-13-cloudinit-template
```

If time permits, export the current VM configs for reference:

```bash
qm config 101
qm config 201
qm config 202
qm config 203
qm config 9000
```

## Phase 2: Optional Staging Before Cutover

This phase is optional. Use it only if the new host can be installed while the old host remains online.

Install the new Proxmox host temporarily as something like:

```text
Hostname: COMMAND001-new.school.local
IP:       192.168.1.111/24
Gateway:  192.168.1.1
DNS:      192.168.1.203 or 192.168.1.1
```

Update Proxmox:

```bash
apt update
apt full-upgrade
reboot
```

Do not restore VMs yet. Before restoring anything, the node must be moved to the final hostname and IP in Phase 4.

## Phase 3: Cutover Start

During the maintenance window, shut down the VMs on the old host:

```bash
qm shutdown 201 --timeout 120
qm shutdown 101 --timeout 120
qm shutdown 202 --timeout 120
qm shutdown 203 --timeout 120
```

Check they are stopped:

```bash
qm list
```

If the old NIC is stable enough, take final backups to the Buffalo NAS after shutdown. Then power off the old host and unplug its network cable.

Use the actual NAS storage ID from `pvesm status`:

```bash
vzdump 101 201 202 203 --storage <nas-storage-id> --mode stop --compress zstd
```

## Phase 4: Install Or Rename New Host To Final Identity

The new host should be `COMMAND001` at `192.168.1.110` before VM restore.

If installing fresh during the maintenance window, use:

```text
Hostname: COMMAND001.school.local
Short name: COMMAND001
IP:       192.168.1.110/24
Gateway:  192.168.1.1
DNS:      192.168.1.203 if DNS001 is online, otherwise 192.168.1.1
```

If the new host was staged temporarily, change these files while the node is still empty:

```bash
nano /etc/hostname
nano /etc/hosts
nano /etc/network/interfaces
```

Expected hostname and hosts mapping:

```text
COMMAND001
```

```text
127.0.0.1       localhost.localdomain localhost
192.168.1.110   COMMAND001.school.local COMMAND001
```

Reboot after changing hostname or management IP:

```bash
reboot
```

Validate on the new host:

```bash
hostname
hostname --fqdn
hostname --ip-address
cat /etc/hosts
pveversion
```

## Phase 5: Restore SSH Trust From Workstation

Because `192.168.1.110` now points to new hardware, clear old SSH host keys from the Windows workstation:

```powershell
ssh-keygen -R 192.168.1.110
ssh-keygen -R COMMAND001
ssh-keygen -R COMMAND001.school.local
```

Add the workstation public key to the new Proxmox host:

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@192.168.1.110 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

Validate SSH access:

```powershell
ssh root@192.168.1.110 hostnamectl
```

## Phase 6: Attach Buffalo NAS Backup Storage

Prefer NFS if the Buffalo NAS supports it:

```bash
pvesm nfsscan 192.168.1.50
pvesm add nfs buffalo-backups --server 192.168.1.50 --export /path/from/nfsscan --content backup,iso
```

Use CIFS/SMB if NFS is unavailable:

```bash
pvesm scan cifs 192.168.1.50 --username <nas-user>
pvesm add cifs buffalo-backups --server 192.168.1.50 --share <share-name> --username <nas-user> --smbversion 3 --content backup,iso
```

If using CIFS, prefer adding the storage through the Proxmox GUI if that is easier for password entry. Do not commit NAS credentials to this repository.

Confirm storage and backup files:

```bash
pvesm status
ls -lh /mnt/pve/buffalo-backups/dump
```

## Phase 7: Restore VMs To Local Proxmox Storage

Restore to local VM storage, typically `local-lvm` or `local-zfs`. The examples below assume `local-lvm`.

First identify the exact newest backup files. Do not pass a wildcard directly to `qmrestore` if more than one backup generation exists.

```bash
ls -1t /mnt/pve/buffalo-backups/dump/vzdump-qemu-203-*
ls -1t /mnt/pve/buffalo-backups/dump/vzdump-qemu-202-*
ls -1t /mnt/pve/buffalo-backups/dump/vzdump-qemu-101-*
ls -1t /mnt/pve/buffalo-backups/dump/vzdump-qemu-201-*
```

Then restore using exact file names:

```bash
qmrestore /mnt/pve/buffalo-backups/dump/<exact-vzdump-qemu-203-file> 203 --storage local-lvm
qmrestore /mnt/pve/buffalo-backups/dump/<exact-vzdump-qemu-202-file> 202 --storage local-lvm
qmrestore /mnt/pve/buffalo-backups/dump/<exact-vzdump-qemu-101-file> 101 --storage local-lvm
qmrestore /mnt/pve/buffalo-backups/dump/<exact-vzdump-qemu-201-file> 201 --storage local-lvm
```

Restore the template if needed:

```bash
ls -1t /mnt/pve/buffalo-backups/dump/vzdump-qemu-9000-*
qmrestore /mnt/pve/buffalo-backups/dump/<exact-vzdump-qemu-9000-file> 9000 --storage local-lvm
```

After restore, confirm VM configs:

```bash
qm list
qm config 203
qm config 202
qm config 101
qm config 201
```

## Phase 8: Start Restored VMs

Start infrastructure services first:

```bash
qm start 203
qm start 202
qm start 101
qm start 201
```

Expected order:

```text
DNS001 first
SQL001 second
APP001 third
WEB001 last
```

## Phase 9: Validate Services

From the Windows workstation:

```powershell
ssh root@192.168.1.110 hostnamectl
ssh debian@192.168.1.203 hostname
ssh debian@192.168.1.202 hostname
ssh debian@192.168.1.200 hostname
ssh debian@192.168.1.210 hostname
```

Check service ports:

```powershell
Test-NetConnection 192.168.1.203 -Port 22
Test-NetConnection 192.168.1.202 -Port 5432
Test-NetConnection 192.168.1.210 -Port 80
Resolve-DnsName web001.school.local -Server 192.168.1.203
```

Check Proxmox VM state:

```bash
qm list
```

## Phase 10: Update `proxmoxctl`

`proxmoxctl` lives on `APP001`:

```text
/home/debian/bin/proxmoxctl
```

It reads environment settings from:

```text
/home/debian/.config/proxmox/env
```

Create a new Proxmox API token on the replacement `COMMAND001`, then update the env file on `APP001`:

```bash
PVE_HOST="https://192.168.1.110:8006"
PVE_TOKEN_ID="..."
PVE_TOKEN_SECRET="..."
```

Test from `APP001`:

```bash
/home/debian/bin/proxmoxctl version
/home/debian/bin/proxmoxctl vms
```

## Phase 11: Configure Ongoing NAS Backups

In the Proxmox GUI:

```text
Datacenter > Backup > Add
```

Suggested settings:

```text
Storage: buffalo-backups
Mode: snapshot
Compression: zstd
Schedule: nightly
Retention: keep-last 7, keep-weekly 4, keep-monthly 3
```

Run a manual test backup after the restored VMs are healthy.

## Rollback Plan

If the new host cannot restore or boot the VMs correctly:

1. Keep the new host powered on only if it is not using conflicting VM IPs.
2. Shut down any restored VMs on the new host.
3. Power the old `COMMAND001` back on.
4. Start the old VMs in order: `203`, `202`, `101`, `201`.
5. Re-check DNS, PostgreSQL, app, and web service reachability.

## Completion Checklist

- [ ] Old `COMMAND001` powered off and disconnected.
- [ ] New hardware installed as `COMMAND001` at `192.168.1.110`.
- [ ] SSH from workstation to `root@192.168.1.110` works.
- [ ] Buffalo NAS storage is attached in Proxmox.
- [ ] VM `203` restored and running as `DNS001`.
- [ ] VM `202` restored and running as `SQL001`.
- [ ] VM `101` restored and running as `APP001`.
- [ ] VM `201` restored and running as `WEB001`.
- [ ] `proxmoxctl` on `APP001` points to `https://192.168.1.110:8006`.
- [ ] Scheduled NAS backups configured and tested.

## References

- Proxmox VE installation: https://pve.proxmox.com/pve-docs/chapter-pve-installation.html
- Proxmox VE storage: https://pve.proxmox.com/pve-docs/chapter-pvesm.html
- Proxmox VE backup and restore: https://pve.proxmox.com/pve-docs/chapter-vzdump.html
- `qmrestore`: https://pve.proxmox.com/pve-docs/qmrestore.1.html
- Renaming a PVE node: https://pve.proxmox.com/wiki/Renaming_a_PVE_node
