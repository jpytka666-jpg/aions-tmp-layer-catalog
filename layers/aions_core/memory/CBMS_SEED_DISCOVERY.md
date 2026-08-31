# CBMS Seed Script Discovery

**Data odkrycia:** 25.12.2025
**Autor analizy:** Claude Code + Marcin

## Krytyczne Pliki

### Seed Script (GŁÓWNY)
```
E:\AI_WORKSPACE\MASTER_CLEAN_SNAPSHOT\CBMS\CBMS_EXTRACT\BACKUP 01\BACKUP 01\AIONS_COMPLETE\direct_memory_inject.py
```

### Backup z dnia seedowania
```
E:\AI_WORKSPACE\MASTER_CLEAN_SNAPSHOT\CBMS\CBMS_EXTRACT\AIONS_ESSENTIAL_BACKUP_20250909_113212\
```

## Mechanizm Seedowania

### Generowanie Chunk ID
```python
chunk_id = "K" + hashlib.sha256(content.encode()).hexdigest()[:12].upper()
```

### Tworzenie DAG (Directed Acyclic Graph)
```python
# Każdy chunk referencuje do 3 poprzednich chunków
references = chunk_references[-3:] if chunk_references else []
```

### Output Directory
```
E:/AIONS_COMPLETE/cbms_memory/chunks/
```

## Seed Chunks (09.09.2025 01:28:39.xxx)

| Chunk ID | Concept | References |
|----------|---------|------------|
| K33EE7E8881CB | programming_python | [] (ROOT) |
| KE701B295F85E | programming_javascript | [python] |
| K49A06F1F962E | programming_systems | [python, js] |
| K8748718B4D4F | programming_databases | [python, js, sys] |
| KC09D82ED999A | programming_web | [js, sys, db] |
| K0FFFE109954D | ai_ml_fundamentals | [sys, db, web] |
| KF92392865CF5 | ai_nlp | [db, web, ml] |
| K9C1895531532 | ai_safety | [web, ml, nlp] |

**Total: 30 seed concepts** in knowledge_base tuple list

## 4 Typy Hashable Chunks

1. **Seed Knowledge** (wartościowe) - z direct_memory_inject.py
2. **Synthesis** (meta-indeks) - kuratorowane podsumowania
3. **Placeholders** (diagnostyczne) - markery systemowe
4. **Raw Output** (śmieci) - nieprzetworzone dane

## Czasowa Struktura

- **Warstwa 1 (Hashable):** 09.09.2025 01:28:39.xxx - batch ~150ms
- **Warstwa 2 (Readable):** 08-09.11.2025 - kuratorowane chunks

## Aliasy Projektu

MAIPA = POLIP = AIONS (ta sama baza kodu, różne nazwy generowane przez AI)

## Pełny Manifest z 09.09.2025

**Total: 136 chunków** w `knowledge_manifest.json`

### Kategorie chunków:
| Kategoria | Ilość | Czas utworzenia |
|-----------|-------|-----------------|
| 30 Core Seeds | 30 | 01:28:39.xxx (~500ms) |
| thinking_methodology_* | 6 | 06:07:06.xxx |
| aions_crla_learning | 6 | 07:24 - 09:47 |
| session_context_save | 9 | 09:58 - 10:36 |
| desktop_files_analysis | 6 | 01:49 - 04:29 |
| test_concept_* | 5 | 10:08:46.xxx |
| general | 14+ | różne |

### 30 Core Seed Concepts:
```
programming_python, programming_javascript, programming_systems, programming_databases,
programming_web, ai_ml_fundamentals, ai_nlp, ai_safety, ai_systems, ai_architecture,
problem_analytical, problem_system_design, problem_optimization, problem_research,
problem_creative, communication_technical, communication_review, communication_teaching,
communication_collaboration, communication_presentation, security_cybersec, data_science,
devops_practices, mathematics, business_analysis, meta_thinking, meta_code_analysis,
meta_learning, meta_quality, meta_integration
```

## Lokalizacje cbms_memory (48 znalezionych)

### AKTYWNE:
- `D:\AIONS-INTEGRATION\aions_core\memory\chunks\` - **526 chunków** (główne)
- `D:\AIONS-INTEGRATION\aions_core\server\cbms_memory.py` - implementacja

### ORIGINAL SEED OUTPUT (PUSTE):
- `E:\AIONS_COMPLETE\cbms_memory\chunks\` - 0 plików (przeniesione!)

### BACKUP Z DNIA SEEDOWANIA:
- `E:\AI_WORKSPACE\MASTER_CLEAN_SNAPSHOT\CBMS\CBMS_EXTRACT\AIONS_ESSENTIAL_BACKUP_20250909_113212\`
  - `cbms_memory\chunks\` - 5 plików (niepełny backup)
  - `cbms_memory\knowledge_manifest.json` - **PEŁNY MANIFEST 136 chunków!**

### KOPIE/BACKUPY:
- `E:\AI_WORKSPACE\MASTER_CLEAN_SNAPSHOT\UNCLASSIFIED\AIONS_COMPLETE\cbms_memory`
- `E:\AJAJAJ\AIONS_COMPLETE\cbms_memory`
- `E:\AJAJAJ\CBMS_EXTRACT\AIONS_ESSENTIAL_BACKUP_20250909_113212\cbms_memory`
- Multiple locations in `IMPORT FROM _F`, `IMPORT FROM_C`, etc.

### GEMINI CODE TRACKER:
- `C:\Users\User\.gemini\antigravity\code_tracker\active\no_repo\*_cbms_memory.py` (4 wersje)

### RELEASE VERSIONS:
- `D:\NEEDS ATENTION\AIONS_CBMS_RELEASE_V3\server\`
- `D:\NEEDS ATENTION\MAPA_LASU_SOLO_CBMS\AIONS_CBMS_RELEASE\server\`

## Powiązane Pliki

- `D:\AIONS-INTEGRATION\aions_core\server\cbms_memory.py` - aktywna implementacja
- `D:\AIONS-INTEGRATION\aions_core\cbms_memory.py` - kopia
- `D:\AIONS-INTEGRATION\aions_core\memory\chunks\` - aktywne chunki
