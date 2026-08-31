# Blend Learning — agenci AIONS

Lokalny, **offline** system uczenia z błędów: **mistake → analyzer → conclusion → meta CBMS**.

## Obowiązek agenta

Przed **ryzykownym twierdzeniem** (status deploy PASS/FAIL, OAuth REAL, miejsce na dysku, git dirty, dostęp SSH):

1. `search_blends` — słowa kluczowe z domeny
2. `cbms_search` — po tagach z blendu
3. Dopiero potem claim z dowodem narzędzia w tej sesji

## Ścieżki

| Co | Gdzie |
|----|-------|
| Schema | `aions_core/memory/blends/blend_schema.json` |
| Biblioteka | `aions_core/memory/blends/blend_lib.py` |
| Seedy (5× 2026-07-11) | `aions_core/memory/blends/seed/` |
| Wnioski | `aions_core/memory/blends/conclusions/` |
| Skrypty | `control_plane/blends/` |

## Użycie (Python 3.11)

```powershell
# Analiza błędu
.\scripts\aions_python.ps1 control_plane\blends\analyze_blend.py BLEND-2026-07-11-hv-partial-vs-fail

# Wniosek + eksport chunka CBMS (plik only — bez prod Chroma)
.\scripts\aions_python.ps1 control_plane\blends\write_conclusion.py BLEND-2026-07-11-hv-partial-vs-fail --export-cbms

# Szukaj przed claimem
.\scripts\aions_python.ps1 control_plane\blends\search_blends.py "Proxmox PASS jump"
```

## Seedy 2026-07-11

1. **HV PARTIAL vs FAIL** — PARTIAL_FAIL ≠ całkowity FAIL
2. **Proxmox .150 PASS** — wymaga jump host, Windows nie pinguje
3. **Google OAuth REAL** — bez credentiali = scaffolding, nie REAL
4. **AVHDX merge ~30GB** — konsolidacja ≠ wolne miejsce na D:
5. **dirty~90 / control_plane untracked** — podawaj precyzyjny `git status`

## CBMS

- Meta-chunk: `aions_core/memory/chunks/KBLENDLEARN001.json`
- Ingest: `aions_core/memory/blends/CBMS_INGEST_NOTE.md` — **ręcznie na dev**, nie prod Chroma

## Dodawanie blendu

1. JSON w `mistakes/` lub `seed/` wg schema
2. `analyze_blend.py` → `write_conclusion.py --export-cbms`
3. Zaktualizuj `blend_manifest.json` (automatycznie przez skrypty)
