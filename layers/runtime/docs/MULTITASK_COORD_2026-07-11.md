# Multitask coordination — 2026-07-11 (wieczór)

**Koordynator:** progress tester · **MCP health:** `ok` (2026-07-11T20:19Z)

## Zadania siblingów

| ID | Agent | Zakres |
|----|-------|--------|
| A | Auto-checkpoint | Reguły → dump Chroma |
| B | Status/docs | HV FAIL, caveat Proxmox jump, OAuth secrets |
| C | Blend learning | blends + analyzer + conclusions + CBMS meta |
| D | Local dev plan | tylko lokalnie, bez paid, bez PARTIAL |

---

## Checklist obowiązkowy (SSOT)

Źródła: [`scripts/aions_automation_limits.md`](../../scripts/aions_automation_limits.md), [`AGENTS.md`](../../AGENTS.md) § MCP health gate.

### Przed automatyzacją

1. **`system_health()`** na `user-aions-context` (prod); jeśli używasz dev → potwierdź `aions-dev`.
2. Błąd transportu / `status != ok` → **STOP**, komunikat: *Reload MCP w Cursor Settings*; zapisz incydent (`memory_store` / `conv_log` tag `MCP_RELOAD`).
3. Po reloadzie użytkownika → **`session_bootstrap()`** raz, potem ponownie `system_health()`.

### Limity czasu i prób

| Operacja | Limit |
|----------|-------|
| Wywołanie MCP | oczekuj ≤ **30s**; max **2** próby (retry raz) |
| Shell status | **30s** |
| Shell build | **120s** |
| Sesja desktop (`desktop_*` / `browser_*`) | **≤180s** (2–3 min) łącznie |
| Pętla snapshot desktop | **120s**, max **5** iteracji |
| `desktop_click` te same współrz. | **30s**, max **3** próby |
| Retry per akcja desktop/browser | **3–5** (nigdy 15–20) |
| Skan subnet **/24** | **zakazany** bez explicit ask użytkownika |
| VMConnect | **1** na sesję bez prośby użytkownika |

### Dyscyplina retry

- Między próbami: **raportuj stan** (błąd, snapshot, coords) — bez ślepego retry.
- **Nie** pętluj `desktop_click` przy błędach MCP.
- User: *timeout* / *zawiesiles sie* / *wisisz* → **STOP**, stan, **jeden** najmniejszy next step.

### Edycje i sekrety

- **Edytuj tylko na E:** `E:\server wiedzy` (canonical); sync na D: przez `scripts\sync_dev_mirror.ps1`.
- **Nie commituj** `.env`, kluczy, credentials OAuth.
- **Nie zmieniaj** bez zgody: `C:\Users\User\.cursor\mcp.json` → `aions-context`, prod Chroma, core `scripts/aions-ctl`.

### Zakazy batch-specific

- **Brak auto-checkpoint na Hyper-V** — HV pozostaje FAIL/manual; nie automatyzuj CP na HV w tym batchu.
- Koordynator **nie** implementuje pełnego blend systemu ani pełnego LOCAL_DEV_PLAN — tylko checklist + gap report.

### Python / routing

- Python **3.11** via `scripts/aions_python.ps1` / `.sh` — nie bare `python`.
- Szukaj plików: **`fast_search`** (Everything); repo content: Read/Grep w workspace.

---

## Stan artefaktów (scan 2026-07-11 ~20:19)

| Oczekiwany artefakt | Status |
|---------------------|--------|
| Reguła CHECKPOINT / auto-checkpoint → Chroma | **GAP** — brak w `.cursor/rules`, brak plików CHECKPOINT/auto-checkpoint |
| Katalog `blends/` (learning system) | **GAP** — brak |
| `LOCAL_DEV_PLAN` (doc) | **GAP** — brak |
| Poprawki status (HV FAIL, Proxmox jump, OAuth) | **w toku** — sibling B; nie weryfikowano diffów |
| Ten plik koordynacji | **OK** |

---

## Notatki z pamięci (`claude_marcin_main`)

- Aktywna faza: **Operator Senses** (Fala 5); Faza 2 Deploy 2/3 (VPS SKIPPED).
- Znane blockery historyczne: MCP reload po transport errors; HV deploy FAIL — nie auto-CP.
- Blend/checkpoint w tym batchu — **artefakty jeszcze nie materializowane** (siblingi w trakcie).

---

## Dla parent agenta

1. Przekaż siblingom ten checklist przed długą automatyzacją.
2. Po zakończeniu A/C/D — ponowny scan `fast_search` + weryfikacja GAPów.
3. Agent B: sprawdź `PLATFORM_MATRIX.md`, `AGENTS.md`, docs OAuth — czy HV=FAIL i Proxmox jump caveat są spójne.
