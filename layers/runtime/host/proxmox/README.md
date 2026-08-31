# Proxmox — Milestone C (Faza 2)

Deploy AIONS on Proxmox VE using Ubuntu 22.04 cloud image + cloud-init.

## Prerequisites

- Proxmox host with SSH access (`root@proxmox`)
- `qm` CLI available
- Storage for VM disk (e.g. `local-lvm`)
- SSH key: `D:\AIONS_DEV\vm\aions-milestone-c\keys\id_ed25519.pub`

## Quick start

From Windows (repo root):

```powershell
# Set Proxmox host and run (requires bash/WSL or Git Bash)
$env:PROXMOX_HOST = 'root@192.168.1.10'
$env:PROXMOX_STORAGE = 'local-lvm'
bash runtime/host/run_milestone_c_proxmox.sh
```

Or copy `run_milestone_c_proxmox.sh` to a machine with `qm` and run there.

## Flow

1. Download Ubuntu 22.04 cloud image (if missing on Proxmox)
2. Create VM `aions-milestone-c` (2 vCPU, 4GB RAM, 40GB disk)
3. Inject cloud-init with SSH key
4. Wait for DHCP + SSH
5. SCP `aions-repo.tgz` to guest
6. Run `guest_milestone_c_run.sh` → reboot → `guest_milestone_c_post_reboot.sh`
7. Write `D:\AIONS_DEV\logs\milestone-c-proxmox\result.json`

## Logs

`D:\AIONS_DEV\logs\milestone-c-proxmox\`

## Notes

- Uses **SCP/tar** for repo — not SMB/CIFS
- Same guest scripts as Hyper-V: `guest_milestone_c_*.sh`

## Install Proxmox host (ISO)

See [INSTALL_FROM_ISO.md](./INSTALL_FROM_ISO.md) for USB or Hyper-V ions-proxmox-host install before running the milestone script.
