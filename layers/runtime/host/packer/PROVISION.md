# Packer golden image — runbook (Faza 8)

Build QCOW2 AIONS host z szablonu `aions-host.pkr.hcl`. Źródło walidacji Milestone C: Proxmox VM **9100** @ **192.168.1.150** (PASS 2026-07-03).

## Prerequisites

| Wymaganie | Sprawdzenie | Uwagi |
|-----------|-------------|-------|
| WSL2 Ubuntu (lub Linux z KVM) | `wsl -l -v` | Domyślnie: dystrybucja `Ubuntu` |
| QEMU | `wsl -d Ubuntu -- which qemu-system-x86_64 qemu-img` | Pakiet `qemu-system-x86` |
| KVM | `wsl -d Ubuntu -- ls -la /dev/kvm` | WSL2: `/dev/kvm` istnieje |
| Grupa `kvm` | `wsl -d Ubuntu -- groups` | Użytkownik build **musi** być w `kvm` |
| Packer ≥ 1.0.9 | `packer version` | Binarnie do `~/bin` lub HashiCorp apt |
| Repo canonical | `E:\server wiedzy` | Skrypt kopiuje `runtime/host/` do VM |
| ~25 GB wolnego | dysk WSL + output | Cloud image + qcow2 20 GB |

### Jednorazowa konfiguracja WSL (jako użytkownik z hasłem sudo)

```bash
# WSL Ubuntu — interaktywnie (wymaga hasła)
sudo apt-get update
sudo apt-get install -y qemu-system-x86 qemu-utils unzip curl

# Packer (bez sudo — do ~/bin)
curl -fsSL -o /tmp/packer.zip \
  https://releases.hashicorp.com/packer/1.15.4/packer_1.15.4_linux_amd64.zip
unzip -o /tmp/packer.zip -d ~/bin
chmod +x ~/bin/packer
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc

# Dostep do KVM (wymagane dla accelerator=kvm)
sudo usermod -aG kvm "$USER"
# Z Windows bez hasla aions (jednorazowo, jako root WSL):
#   wsl -d Ubuntu -u root -- usermod -aG kvm aions
# Nowa sesja WSL (grupa kvm): wsl --shutdown, potem ponowne wsl
```

## Walidacja (Windows, bez buildu)

```powershell
powershell -ExecutionPolicy Bypass -File "E:\server wiedzy\runtime\host\packer\build_image.ps1" -ValidateOnly
```

Oczekiwany wynik: `ValidateOnly OK`.

## Walidacja szablonu (WSL)

```bash
export PATH="$HOME/bin:$PATH"
cd "/mnt/e/server wiedzy/runtime/host/packer"
# user-data musi istniec (build_image.ps1 lub recznie z cloud-init-user-data.yaml)
packer init aions-host.pkr.hcl
packer validate -var 'ssh_private_key_file=.packer-build-key/id_rsa' aions-host.pkr.hcl
# Oczekiwane: The configuration is valid.
```

## Build QCOW2 (zalecane: wrapper Windows)

```powershell
powershell -ExecutionPolicy Bypass -File "E:\server wiedzy\runtime\host\packer\build_image.ps1"
```

Skrypt uruchamia `wsl` → `bash -lc` z jawnym Linux `PATH` (`$HOME/bin`, `/usr/bin`, …), więc PowerShell **nie** nadpisuje `$PATH` wartościami z Windows (wcześniejszy blocker: `qemu-system-x86_64: not found`).

Czas: **ok. 20-45 min**.

### Build QCOW2 (WSL — ręcznie, alternatywa)

```bash
export PATH="$HOME/bin:/usr/bin:/bin:$PATH"
cd "/mnt/e/server wiedzy/runtime/host/packer"
packer init aions-host.pkr.hcl
packer build -force aions-host.pkr.hcl
```
## Co robi szablon

1. Pobiera Ubuntu 22.04 cloud image (checksum z SHA256SUMS).
2. Montuje NoCloud seed (`cd_label=cidata`, `cd_files`: `meta-data` + `user-data`) — **wymagane**, inaczej SSH nie wstaje (brak użytkownika/hasła w cloud image).
3. `build_image.ps1` generuje parę kluczy `.packer-build-key/id_rsa` i renderuje `cidata/user-data` z szablonu `cloud-init-user-data.yaml` (wzorzec: `runtime/host/vps/cloud-init-user-data.yaml`).
4. Boot QEMU (KVM, 4 GB RAM, 2 vCPU, disk 20 GB).
5. Instaluje pakiety: git, python3.11, curl, jq, rsync.
6. Kopiuje `runtime/host/` → `/opt/aions/source/`.
7. Uruchamia `install_aions_host.sh`, `first_boot_setup.sh`, identity, `validate_install.sh --with-runtime --strict-health`.
8. Zapisuje manifest post-processor.

## TROUBLESHOOTING — SSH timeout (2026-07-04)

Diagnoza po dwóch failach buildu (4a47dadc: brak seed; 5693543c: seed był, SSH nadal timeout ~31 min).

| Sprawdzone | Wynik |
|------------|-------|
| `cd_label=cidata` + 2 pliki w ISO | OK — log: `UPDATE: 2 files added` |
| `ssh_private_key_file` vs `authorized_keys` | OK — klucze zgodne (`.packer-build-key/id_rsa.pub`) |
| Port forward SSH (Packer → 127.0.0.1) | OK — `Using SSH communicator`, port dynamiczny |
| `use_communicator` | SSH (domyślnie) — nie WinRM |
| virtio vs ide (CD) | Packer montuje NoCloud ISO poprawnie (Rock Ridge + label) |

**Przyczyna (5693543c):** `build_image.ps1` pisał `cidata/user-data` przez `Set-Content -Encoding UTF8` → **UTF-8 BOM** (`EF BB BF`) przed `#cloud-config`. Cloud-init **ignoruje** plik z BOM — użytkownik `ubuntu` i klucz SSH nigdy nie są stosowane mimo poprawnego ISO.

**Fix:** `Write-CloudInitFile` — UTF-8 **bez BOM**, końcówki linii **LF**. Po każdej regeneracji:

```powershell
Format-Hex "...\cidata\user-data" -Count 4
# Oczekiwane: 23 63 6C 6F (#clo) — NIE EF BB BF
```

**Debug (opcjonalnie):** krótki test przed pełnym buildem (~5 min):

```bash
cd "/mnt/e/server wiedzy/runtime/host/packer"
# po Prepare-PackerCidata / build_image.ps1 — sprawdź hex user-data (brak BOM)
Format-Hex cidata/user-data -Count 4   # PowerShell: 23 63 6C 6F
packer build -force -var 'ssh_private_key_file=.packer-build-key/id_rsa' aions-host.pkr.hcl
# pierwsze ~3 min: w logu powinno pojawić się połączenie SSH, nie 31 min timeout
```

W `aions-host.pkr.hcl` tymczasowo dodaj do `qemuargs` serial do debug bootu:

```hcl
["-serial", "file:/tmp/packer-serial.log"],
```

albo VNC z logu (`vnc://127.0.0.1:59xx`) + w VM: `sudo cloud-init status --long`, `journalctl -u ssh`.

## Znane problemy (2026-07-03)

| Problem | Przyczyna | Fix |
|---------|-----------|-----|
| `Timeout waiting for SSH` (brak seed) | Cloud image bez cloud-init | `cd_files` + `cloud-init-user-data.yaml` (fix 2026-07-04, 4a47dadc) |
| `Timeout waiting for SSH` (seed jest) | BOM/CRLF w `user-data` z PowerShell | `Write-CloudInitFile` w `build_image.ps1` (fix 2026-07-04, 5693543c) |
| `qemu-system-x86_64: not found in $PATH` | PowerShell / WSL z Windows PATH | Uzyj `build_image.ps1` (bash -lc + jawny PATH) lub reczny bash |
| Brak dostępu do `/dev/kvm` | Użytkownik poza grupą `kvm` | `sudo usermod -aG kvm $USER` + restart WSL |
| Packer brak w Windows | Brak instalacji natywnej | Build wyłącznie w WSL/Linux |
| `sudo` wymaga hasła w WSL | Domyślne dla `aions` | Instalacja pakietów jednorazowo interaktywnie |

## Powiązane

- `manifest.yaml` — metadane artefaktów i źródeł (Proxmox 9100, Hyper-V)
- `build_image.ps1` — wrapper Windows (`-ValidateOnly` / pelny build przez WSL + QEMU/KVM)
- Milestone C Proxmox: `runtime/host/proxmox/README.md`
- Notatki obrazu: `runtime/host/build_host_image_notes.md`

## Status Fala 4 (2026-07-03)

| Krok | Status |
|------|--------|
| `build_image.ps1 -ValidateOnly` | **PASS** |
| Proxmox 9100 @ 192.168.1.150 Milestone C | **PASS** |
| SSH ProxyCommand tunnel E2E | **PASS** |
| `packer init` + `packer validate` (WSL) | **PASS** |
| `packer build` -> qcow2 | **READY** — `build_image.ps1` + uzytkownik w grupie `kvm` (2026-07-03) |

