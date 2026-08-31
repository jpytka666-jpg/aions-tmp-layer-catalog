# AIONS Node (Faza 6 MVP)

Worker resource abstraction — **not** a chat endpoint.

## Schema

See `schema.json`. Required fields: `node_id`, `host`. Optional: `capabilities[]`, `memory_mb`, `tools[]`, `health`, `load`, `permissions[]`.

## Registry

- Code: `control_plane/node_registry.py`
- Persisted state: `runtime/state/node_registry.json`
- API: `POST/GET /v1/nodes`, `POST /v1/nodes/{id}/heartbeat` (via `server/app.py`)

## Install stub (Ubuntu)

```bash
sudo bash runtime/host/install_aions_node.sh --node-id my-vm --core-url http://127.0.0.1:8765
```

If Core is unreachable, registration is written to `/var/lib/aions/node_registration.json` (or `$AIONS_STATE_DIR`).

## Register local node (3 commands)

```powershell
cd "E:\server wiedzy"
.\scripts\aions_python.ps1 scripts\test_node_registry.py
curl -X POST http://127.0.0.1:8765/v1/nodes/register -H "Content-Type: application/json" -d "{\"node_id\":\"windows-primary\",\"host\":\"localhost\",\"capabilities\":[\"mcp\"],\"tools\":[\"system_health\"]}"
curl http://127.0.0.1:8765/v1/nodes
```

## Heartbeat (~60s)

Client: `scripts/aions_node_heartbeat.py` (Windows: `scripts/aions_node_heartbeat.ps1`).

```powershell
.\scripts\aions_python.ps1 scripts\aions_node_heartbeat.py --once
.\scripts\aions_python.ps1 scripts\aions_node_heartbeat.py --interval 60
```

Linux systemd example: `runtime/node/aions-node-heartbeat.service.example`.

API: `POST /v1/nodes/{node_id}/heartbeat` with JSON `{"health":"ok","load":0.1}`.

## Proxmox guest register (2026-07-12)

**REGISTERED from Windows Core** — `node_id=proxmox-9100`, `host=192.168.1.150` (metadata from known PASS; no live SSH required for registry entry).

Known-good facts (do not reinvent):
- Hypervisor: `192.168.1.220:8006` (pve) — Milestone C PASS 2026-07-03
- Guest VM 9100: `192.168.1.150` — health `:8765` via jump `root@.220 → ubuntu@.150` (confirmed 2026-07-11)
- Ping `.150` from Windows: FAIL (expected; NAT/jump only)
- WSL key on `D:\...id_ed25519` is `0777` — use `/home/aions/.ssh/aions_milestone_c_key` (600) for live SSH, not NTFS mount

Live guest enroll still optional: `TMPDIR=/tmp bash runtime/host/install_aions_node.sh --dry-run --node-id proxmox-9100 --core-url http://127.0.0.1:8765` via two-hop SSH (see `runtime/docs/CONTROL_PLANE_E2E.md`).
