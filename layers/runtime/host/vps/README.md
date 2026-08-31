# VPS Deploy — Faza 2 (Hetzner / DO)

Deploy AIONS on a cloud VPS using Ubuntu 22.04 + cloud-init + Milestone C.

## Spec (default)

| Param | Value |
|-------|-------|
| Provider | Hetzner Cloud |
| Type | CX22 (2 vCPU, 4 GB, 40 GB) |
| Region | nbg1 or fsn1 |
| OS | Ubuntu 22.04 |
| SSH key | `D:\AIONS_DEV\vm\aions-milestone-c\keys\id_ed25519.pub` |

## Option A — Automated (Hetzner CLI)

```powershell
$env:HCLOUD_TOKEN = '<your-api-token>'   # session only, never commit
powershell -ExecutionPolicy Bypass -File runtime/host/vps/provision_hetzner.ps1
powershell -ExecutionPolicy Bypass -File runtime/host/continue_milestone_c_vps.ps1
```

Logs: `D:\AIONS_DEV\logs\milestone-c-vps\`

## Option B — Manual (Hetzner Console)

1. [console.hetzner.cloud](https://console.hetzner.cloud) → Create Server
2. CX22, Ubuntu 22.04, nbg1
3. Add SSH key (paste `id_ed25519.pub`)
4. Cloud config → paste rendered YAML from:
   `D:\AIONS_DEV\logs\milestone-c-vps\user-data-rendered.yaml`
   (generate: run `provision_hetzner.ps1` without token — writes YAML only)
5. Firewall: inbound TCP 22 (SSH); optional 8765 from your IP
6. Save public IP to `D:\AIONS_DEV\logs\milestone-c-vps\vps.env`:
   ```
   VPS_IP=<public-ip>
   ```
7. Run Milestone C:
   ```powershell
   powershell -File runtime/host/continue_milestone_c_vps.ps1 -Ip <public-ip>
   ```

## Cloud-init template

[`cloud-init-user-data.yaml`](cloud-init-user-data.yaml) — replace `${SSH_PUBLIC_KEY}` with pubkey contents.

## After boot

Same flow as Hyper-V:

```powershell
powershell -File runtime/host/continue_milestone_c_vps.ps1 -Ip <VPS_IP>
```

Result: `D:\AIONS_DEV\logs\milestone-c-vps\result.json` with `strict_health: PASS`

## Notes

- Repo packed to WSL `/tmp` (not `/mnt/d`) — avoids corrupt tarball
- `guest_pre_install.sh` fixes DNS stub (127.0.0.53) before apt
- host-linux: API daemon ON, MCP stdio on-demand (not systemd daemon)
- No CIFS — SCP/tar only
