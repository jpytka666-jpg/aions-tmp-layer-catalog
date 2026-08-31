# Plan lokalny AIONS — 7 dni (2026-07-11 → 2026-07-18)

**Operator:** Marcin  
**Canonical:** `E:\server wiedzy`  
**Powiązane:** [AGENTS.md](../../AGENTS.md), [AIONS_OS_ROADMAP.md](../../.claude/specs/AIONS_OS_ROADMAP.md), [OPERATOR_NEXT_STAGES.md](../../.claude/specs/OPERATOR_NEXT_STAGES.md), [PLATFORM_MATRIX.md](PLATFORM_MATRIX.md)

> Plan **wyłącznie lokalny** — bez płatnego VPS/chmury, bez SaaS LLM, bez auto-checkpointów Hyper-V.  
> Statusy milestone'ów: **PASS** | **FAIL** | **SKIPPED** — **nigdy PARTIAL**.

---

## Stan wyjściowy (2026-07-11 wieczór)

| Obszar | Stan | Dowód |
|--------|------|-------|
| Orchestrator + CBMS gate | **PASS** | `runtime/docs/orchestrator_smoke.json`, `orchestrator_smoke_recheck.json` |
| Proxmox health API | **PASS** (jump SSH) | `runtime/docs/milestone_c_session_2026-07-11.json` §2 |
| Hyper-V VM | **FAIL** (Off, I/O) | Ten sam plik §1 — PausedCritical, brak stabilnego SSH |
| AVHDX merge | **PASS** (ręczny) | Orphan AVHDX scalony do parent VHDX (2026-07-11) |
| D: wolne miejsce | **FAIL** (~29 MB) | `sync_dev_mirror.ps1` ERROR 112; root blocker |
| Blend → Chroma | **GAP** | Brak katalogu `blends/`, brak reguły CHECKPOINT |
| OAuth secrets | **GAP** | Szkielet w `runtime/integrations/`; brak tokenów w `runtime/secrets/` |

**Root blocker:** pełny dysk D: (Hyper-V VHD + mirror + cache) → najpierw **M1 Dysk**.

---

## Polityka anty-PARTIAL

1. **Jeden wynik na milestone** — albo PASS, albo FAIL, albo SKIPPED (z uzasadnieniem).  
   Wynik typu „działa częściowo”, „PARTIAL_FAIL”, „90% done” → **FAIL** do momentu pełnego kryterium.

2. **SKIPPED wymaga decyzji** — jawny powód (np. brak kabla Ethernet, brak zgody na OAuth, brak miejsca na D:).  
   SKIPPED ≠ sukces; nie liczy się do postępu fali operatora.

3. **Dowód PASS** — artefakt plikowy (JSON/log/exit 0) + krótki opis komendy.  
   Bez artefaktu = **FAIL**, nawet jeśli „wydaje się OK”.

4. **Retry** — max 2 próby na operację MCP, 3 na desktop; między próbami raport stanu.  
   Po wyczerpaniu → **FAIL**, nie PARTIAL.

5. **Hyper-V** — **auto-checkpoint OFF** (już wyłączone); **brak auto-CP w tym planie**.  
   HV to opcjonalny M2; domyślnie **SKIPPED** bez kabla LAN.

6. **Chmura / płatne API** — **zakazane** w tym planie.  
   LLM: tylko lokalny GGUF / llama.cpp (`llm_mouth`, `AIONS_LLM_PROVIDER=llamacpp`).  
   HF: tylko lokalne modele / GGUF — bez pobierania w chmurze bez miejsca na D:.

---

## Ograniczenia planu

| Zasada | Szczegół |
|--------|----------|
| Brak paid VPS | VPS Hetzner **SKIPPED** (decyzja 2026-07-10); Faza 2 zamknięta 2/3 |
| LLM lokalnie | GGUF / llama.cpp; zero OpenAI/Anthropic API w smoke |
| HF lokalnie | `D:\LOCAL LLM MODELS` lub cache `D:\AIONS_DEV\cache`; brak download bez ≥10 GB wolnego na D: |
| HV auto-CP | **OFF** — nie włączać AutomaticCheckpoints; nie automatyzować CP |
| Edycje | Tylko **E:** canonical; sync → `scripts\sync_dev_mirror.ps1` |
| Sekrety | Tylko `runtime/secrets/` (gitignored); **nigdy** w repo / commit |
| Proxmox | Dostęp przez **jump**: `root@192.168.1.220` → `ubuntu@192.168.1.150` (klucz `aions_milestone_c_key`) |

---

## Milestone'y — kolejność obowiązkowa

### M1 — Dysk D: (dzień 1 · 2026-07-11/12)

**Cel:** ≥ **10 GB** wolnego na `D:` (minimum operacyjne dla mirror + HV VHD I/O).

| # | Akcja | Kryterium PASS |
|---|-------|----------------|
| 1.1 | Pomiar wolnego miejsca | `(Get-PSDrive D).Free -ge 10GB` |
| 1.2 | Usunięcie / przeniesienie orphan AVHDX, starych checkpointów HV (już merge — weryfikacja braku `.avhdx`) | Brak plików `*.avhdx` w `D:\AIONS_DEV\vm\` (lub katalog pusty) |
| 1.3 | Pełny `sync_dev_mirror.ps1` | Exit 0, brak ERROR 112 |
| 1.4 | Weryfikacja cache AIONS | `D:\AIONS_DEV\cache` istnieje; pip/temp nie na pełnym wolumenie |

**Wynik:** ☐ PASS ☐ FAIL ☐ SKIPPED  
**Artefakt:** `runtime/docs/m1_disk_2026-07.json` — `{ "free_bytes", "sync_exit", "ts" }`

**Marcin fizycznie:** zwolnij D: (VHD, embeddings mirror ~1.8 GB, stare logi). Bez M1 PASS → **M2–M7 = SKIPPED** (kaskada).

---

### M2 — Hyper-V opcjonalny (dzień 2 · 2026-07-12/13)

**Cel:** Potwierdzić stan VM **bez auto-CP**; opcjonalnie GREEN po kablu Ethernet.

| # | Akcja | Kryterium |
|---|-------|-----------|
| 2.1 | VM `aions-milestone-c` = **Off** | PASS jeśli Off i brak PausedCritical w logu |
| 2.2 | AutomaticCheckpoints = **Disabled** | PASS jeśli wyłączone (Get-VM) |
| 2.3 | Start-VM + SSH (tylko jeśli kabel Intel I219-LM + AIONS-External na LAN) | PASS = SSH + `validate_install.sh --strict-health` GREEN |

**Domyślny wynik bez kabla:** **SKIPPED** (2.3), **PASS** (2.1 + 2.2) — VM Off, auto-CP off, merge done.

**Wynik:** ☐ PASS ☐ FAIL ☐ SKIPPED  
**Artefakt:** wpis w `runtime/docs/m2_hv_2026-07.json`

**Zakaz:** auto-checkpoint, merge AVHDX przez skrypt agenta, pętla Start-VM >3 razy.

---

### M3 — OAuth lokalne sekrety (dzień 3 · 2026-07-13/14)

**Cel:** Google Calendar **read-only** jako pierwsza integracja (mniej wrażliwe niż Gmail).

| # | Akcja | Kryterium PASS |
|---|-------|----------------|
| 3.1 | Katalog `runtime/secrets/` (gitignored) | Istnieje, brak w `git status` |
| 3.2 | OAuth Desktop client JSON | `runtime/secrets/google_calendar_oauth.json` (0600) |
| 3.3 | Flow zgody | `runtime/integrations/calendar/oauth_skeleton.py` → token w `runtime/secrets/google_calendar_token.json` |
| 3.4 | Read-only smoke | `list_events` zwraca ≥0 wydarzeń bez błędu API (pusty kalendarz = OK) |

**Scope read-only (Fala 5):** tylko odczyt; **bez** send/modify/delete mimo szkieletu write w README.

**Wynik:** ☐ PASS ☐ FAIL ☐ SKIPPED (brak konta Google / brak czasu)  
**Artefakt:** `runtime/docs/m3_oauth_2026-07.json` — `{ "token_exists", "list_events_ok", "scopes" }` — **bez wartości sekretów**

---

### M4 — Higiena commitów (dzień 4 · 2026-07-14/15)

**Cel:** Repo gotowe do sensownych commitów bez wycieku sekretów i śmieci.

| # | Akcja | Kryterium PASS |
|---|-------|----------------|
| 4.1 | `git status` czysty względem sekretów | Brak `.env`, `runtime/secrets/*`, kluczy SSH w staged |
| 4.2 | `.gitignore` obejmuje `runtime/secrets/`, `*.avhdx`, cache | Pliki istnieją w ignore |
| 4.3 | Pre-commit / ręczny grep sekretów | Brak `client_secret`, `refresh_token` w tracked files |
| 4.4 | Jedna sesja „commit hygiene” | Marcin decyduje co commitować; agent **nie commituje** bez explicit ask |

**Wynik:** ☐ PASS ☐ FAIL ☐ SKIPPED  
**Artefakt:** `runtime/docs/m4_commit_hygiene_2026-07.json` — `{ "secrets_clean", "gitignore_ok" }`

---

### M5 — Operator Senses RO (dzień 5–6 · 2026-07-15/16)

**Cel:** Fala 5 — read-only kalendarz (+ opcjonalnie Gmail RO) w MCP / control plane.

| # | Akcja | Kryterium PASS |
|---|-------|----------------|
| 5.1 | MCP lub API tool `operator_read_calendar` | Zwraca JSON wydarzeń, limit N, read-only |
| 5.2 | Polityka | Brak auto-odpowiedzi, brak usuwania (trust L0–L3 design) |
| 5.3 | Smoke z orchestratora | Pytanie „co mam jutro?” → CBMS gate + calendar context w odpowiedzi |
| 5.4 | (Opcja) Gmail RO | **SKIPPED** jeśli kalendarz wystarczy; inaczej ten sam wzorzec co M3 |

**Wynik:** ☐ PASS ☐ FAIL ☐ SKIPPED  
**Artefakt:** `runtime/docs/m5_operator_senses_2026-07.json`

**Zależność:** M3 PASS (token kalendarza).

---

### M6 — Blend → Chroma loop (dzień 7 · 2026-07-17/18)

**Cel:** Minimalny cykl uczenia: blend (wnioski sesji) → analiza → zapis do Chroma → meta CBMS.

| # | Akcja | Kryterium PASS |
|---|-------|----------------|
| 6.1 | Katalog `blends/` w repo lub `runtime/blends/` | Struktura: `{session_id}.json` z wnioskami |
| 6.2 | Skrypt / reguła CHECKPOINT | Po N wywołaniach MCP → `memory_store` + opcjonalny dump jsonl |
| 6.3 | Analyzer | Jedno narzędzie (np. `scripts/blend_analyze.py`) — czyta blend, emituje conclusions |
| 6.4 | Chroma ingest | `memory_store` / `ingest_tier1_chroma.py` — nowy doc widoczny w `memory_recall` |
| 6.5 | Meta CBMS (opcjonalnie) | Chunk lub wpis manifestu opisujący blend — **SKIPPED** jeśli tylko Chroma wystarczy |

**Wynik:** ☐ PASS ☐ FAIL ☐ SKIPPED  
**Artefakt:** `runtime/docs/m6_blend_chroma_2026-07.json` + przykładowy `blends/2026-07-18_example.json`

**Zależność:** M1 PASS (miejsce na D: + sync); M4 PASS (brak sekretów w blendach).

---

## Macierz dowodów (evidence SSOT)

| Dowód | Oczekiwany stan | Plik / komenda |
|-------|-----------------|----------------|
| Orchestrator PASS | `ok: true` | `scripts/aions_python.ps1 control_plane/orchestrator_loop.py --mcp-smoke` → `runtime/docs/orchestrator_smoke.json` |
| CBMS gate PASS | hit/miss + compose | Ten sam smoke; `control_plane/cbms_gate.py` |
| Proxmox via jump | health `status: ok` | SSH: `220 → 150`, `curl -s 127.0.0.1:8765/health` |
| HV Off | VM stopped | `Get-VM aions-milestone-c` → State Off |
| Merge done | brak orphan AVHDX | Inspekcja `D:\AIONS_DEV\vm\` |
| Zero SaaS | tylko local GGUF | `orchestrator_smoke_recheck.json` note |

---

## Harmonogram 7 dni

| Dzień | Data | Milestone | Priorytet |
|-------|------|-----------|-----------|
| 1 | 2026-07-11/12 | **M1 Dysk** | 🔴 blokujący |
| 2 | 2026-07-12/13 | **M2 HV opcjonalny** | 🟡 SKIPPED bez LAN |
| 3 | 2026-07-13/14 | **M3 OAuth secrets** | 🟢 |
| 4 | 2026-07-14/15 | **M4 Commit hygiene** | 🟢 |
| 5–6 | 2026-07-15/16 | **M5 Operator Senses RO** | 🟢 |
| 7 | 2026-07-17/18 | **M6 Blend→Chroma** | 🟢 |

---

## Definicja zamknięcia tygodnia

Plan uznany za **PASS** tylko gdy:

- **M1 = PASS** (obowiązkowy)
- **M3 + M4 + M5 = PASS** (rdzeń Operator Senses)
- **M2** = PASS lub SKIPPED (uzasadniony)
- **M6** = PASS lub SKIPPED (jeśli sibling blend nie dostarczył artefaktów)

Plan **FAIL** jeśli M1 FAIL po 2 dniach lub M5 FAIL po M3 PASS.

---

## Następny krok (jutro rano)

1. Marcin: zwolnij **≥10 GB** na D: (VHD, stare logi, duplikaty embeddings).
2. Agent: uruchom M1.3 `sync_dev_mirror.ps1`, zapisz `m1_disk_2026-07.json`.
3. **Nie** dotykać Hyper-V auto-CP; VM zostaje **Off** do decyzji o kablu Ethernet.

---

## Changelog

| Data | Zmiana |
|------|--------|
| 2026-07-11 | Utworzono plan (redo po API-limit fail); binary PASS/FAIL/SKIPPED; kolejność disk→HV→OAuth→commit→Senses→blend |

*Dokument w `runtime/docs/` — nie commitować bez prośby Marcina.*
