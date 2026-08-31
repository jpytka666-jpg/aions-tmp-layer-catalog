# Control Plane E2E — tunel SSH (dwa hopy)

Snapshot: 2026-07-03 · PASS: sesja `1d095c07` · **Potwierdzone 2026-07-11:** health `.150` tylko via jump `.220`; ping `.150` z Windows host **FAIL**

## Kontekst

| Host | IP | Uwagi |
|------|-----|-------|
| Windows (dev) | `192.168.1.171` | Brak trasy do gości `.150`/`.186` — ping/SSH **FAIL** (weryfikacja 2026-07-11) |
| Proxmox | `192.168.1.220` | SSH `root`, klucz `id_ed25519` |
| VM 9100 (milestone C) | gość `192.168.1.150` | API tylko na `127.0.0.1:8765`, user `ubuntu` |

E2E z Windows wymaga **dwu hopów**: Proxmox → gość, potem Windows → Proxmox.

Klucz: `D:\AIONS_DEV\vm\aions-milestone-c\keys\id_ed25519` (na Proxmoxie też `/tmp/aions_mc_key`).

## Procedura (działająca)

**0.** Sync repo (jeśli test z mirror D:):

```powershell
.\scripts\sync_dev_mirror.ps1
```

**1.** VM 9100 włączona na Proxmox (z Windows):

```powershell
ssh -i D:\AIONS_DEV\vm\aions-milestone-c\keys\id_ed25519 root@192.168.1.220 "qm status 9100; qm start 9100"
```

**2.** Hop 1 — tunel na Proxmoxie (gość → localhost Proxmoxa):

```powershell
ssh -i D:\AIONS_DEV\vm\aions-milestone-c\keys\id_ed25519 root@192.168.1.220 `
  "ssh -f -N -i /tmp/aions_mc_key -L 127.0.0.1:8765:127.0.0.1:8765 ubuntu@192.168.1.150"
```

Weryfikacja na Proxmoxie: `curl http://127.0.0.1:8765/health` → 200.

**3.** Hop 2 — tunel z Windows (Proxmox → localhost Windows), proces w tle:

```powershell
ssh -N -L 8765:127.0.0.1:8765 -o ServerAliveInterval=30 `
  -i D:\AIONS_DEV\vm\aions-milestone-c\keys\id_ed25519 root@192.168.1.220
```

**4.** Test E2E (drugi terminal):

```powershell
curl http://127.0.0.1:8765/health
python scripts/test_control_plane.py --remote-url http://127.0.0.1:8765/health
```

Oczekiwany wynik: `remote E2E OK`.

## Nie działa z Windows

Bezpośredni tunel do gościa (brak routy z `.171`):

```powershell
# timeout — NIE używać
ssh -L 8765:127.0.0.1:8765 -i ... ubuntu@192.168.1.150 -N
```

`-J root@192.168.1.220 ubuntu@192.168.1.150` — niestabilne (auth/routing); użyj dwóch hopów powyżej.

## Fallback Hyper-V

Gość `192.168.1.186` — z Windows też unreachable; gdy Proxmox niedostępny, uruchom VM lokalnie (`Start-VM aions-milestone-c`) i tunel bezpośrednio do `.186` (tylko gdy ping/SSH działa).

## Zmienne

- `AIONS_REMOTE_API_URL=http://127.0.0.1:8765` — po zestawieniu tunelu
- `AIONS_PROXMOX_GUEST_API=http://192.168.1.150:8765` — bezpośrednio z Windows: timeout

## Skrypt

`scripts/test_control_plane.py`: lokalny smoke + `--remote-url URL` + `--remote-only` (`-h` — pomoc).
