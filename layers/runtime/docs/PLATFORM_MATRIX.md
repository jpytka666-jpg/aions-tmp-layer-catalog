# AIONS Platform Matrix — Faza 2 (Deploy Anywhere)

**Kryterium PASS:** `install → boot → GREEN` (`validate_install.sh --with-runtime --strict-health`)

| Platforma | Arch | Status | Skrypt testowy | Ostatni PASS | Notatki |
|-----------|------|--------|----------------|--------------|---------|
| Hyper-V | amd64 | **PASS** | `runtime/host/continue_milestone_c.ps1` | 2026-07-02 | VM `aions-milestone-c` @ 192.168.1.186; SCP/tar repo |
| WSL dev | amd64 | STAGING | `aions-ctl up` + health | GREEN | Nie liczy się jako deploy target |
| Proxmox | amd64 | **PASS** | `runtime/host/run_milestone_c_proxmox.sh` | 2026-07-03 | VM 9100 @ 192.168.1.150; NAT via Proxmox host; `/tmp/aions-repo.tgz` |
| VPS (cloud-init) | amd64 | **SKIPPED** | `runtime/host/continue_milestone_c_vps.ps1` | — | Decyzja użytkownika 2026-07: brak płatnej chmury; automation Hetzner CX22 zostaje opcjonalna w `runtime/host/vps/` |
| Oracle Cloud ARM | aarch64 | TODO | TBD | — | Po Fazie 2 (VPS SKIPPED) |
| Raspberry Pi | aarch64 | TODO | TBD | — | Packer aarch64 |
| AIONS Image (qcow2) | amd64 | **PASS** | `runtime/host/packer/build_image.ps1` | 2026-07-03 | build #4 (`34e12370`); artifact `output-aions-host/packer-aions_ubuntu` (~16.5 GiB); validate 33/33 GREEN |
| Bare metal | amd64 | TODO | ISO (Faza 8) | — | Po image MVP (qcow2 PASS → ISO następny) |
| Docker systemd | amd64 | PARTIAL | `docker_milestone_c_systemd_run.sh` | layout+health | Brak linger strict; nie deploy target |

## Stan operacyjny (weryfikacja 2026-07-11)

| Platforma | Stan **bieżący** | Uwaga |
|-----------|------------------|-------|
| Hyper-V | **FAIL** | VM `aions-milestone-c` **Off**; brak stabilnego L3/SSH (Wi-Fi external switch, D: prawie pełny, brak kabla Ethernet). Historyczny PASS 2026-07-02 w tabeli powyżej — nie oznacza działającego gościa dziś. |
| Proxmox | **PASS** (via jump) | VM 9100 @ `192.168.1.150` — health OK tylko przez SSH jump `root@192.168.1.220 → ubuntu@.150`. Ping `.150` z Windows host **FAIL** (timeout). |

## Logi PASS

- Hyper-V: `D:\AIONS_DEV\logs\milestone-c-hyperv\result.json`
- Proxmox: `D:\AIONS_DEV\logs\milestone-c-proxmox\result.json`
- VPS (SKIPPED): automation w `runtime/host/vps/` — nie wymagane do zamknięcia Fazy 2 (2026-07-10)
- Packer qcow2: `runtime/host/packer/output-aions-host/packer-aions_ubuntu` (build #4, 2026-07-03)

## Zasady deploy (reguła `aions-deploy`)

1. `TMPDIR=/tmp` — nigdy CIFS dla apt/dpkg
2. Repo na gościa: **SCP/tar** (preferowane) lub lokalny mirror
3. Skrypty `.sh` — tylko LF (Unix line endings)
4. Każda nowa platforma = wiersz w tej tabeli + skrypt w `runtime/host/`
