# AIONS — odległość od celów Marcina (2026-07-12)

**Źródła:** strategia z czatu Marcina · dowody repo `E:\server wiedzy` · web (Sloppix)  
**Wygenerowano:** 2026-07-12 · **bez commitu**

---

## SEKCJA 1 — CZŁOWIEK (prosty PL)

### Jak daleko jesteśmy?

**Rdzeń „manager + węzły” jest w połowie drogi (~48%).**  
Masz już mózg w `control_plane/`, pamięć CBMS/Chroma, MCP i deploy hosta.  
**Brakuje** pełnej orkiestracji wielu workerów — ale **Faza 6 ma już rusztowanie MVP** (rejestr + API + install stub + heartbeat + dispatch stub + wpis `proxmox-9100`).

**Co działa dziś:**
- Host AIONS na Ubuntu (Hyper-V/Proxmox/Packer qcow2) — **PASS** historycznie
- Control plane MVP: planner, executor, scheduler, API, pętla `orchestrator_loop`
- Kalendarz Google — **GREEN** (Operator Senses)
- Blends + checkpointy sesji — **są**, ale pełny loop M6 nie zamknięty artefaktem PASS
- **Faza 6 MVP:** `control_plane/node_registry.py`, `/v1/nodes`, `install_aions_node.sh`, `runtime/node/schema.json`
- **Node heartbeat:** `scripts/aions_node_heartbeat.py` + `POST /v1/nodes/{id}/heartbeat` — smoke OK lokalnie 2026-07-12; oba węzły (`windows-primary`, `proxmox-9100`) heartbeat OK 2026-07-12 PM
- **Node dispatch stub:** `control_plane/node_dispatch.py` + `POST /v1/nodes/{id}/dispatch` — local OK, remote stub OK

**Co blokuje:**
- Dysk **D:** (~29 MB wolnego w planie 2026-07-11) — sync/mirror
- **Faza 6 Distributed** — **MVP ~32%** (registry + API + install stub + heartbeat + dispatch stub; `proxmox-9100` w registry; **live SSH jump PASS** 2026-07-12 PM po `qm start 9100`: `.220→ubuntu@.150` hostname `aions`; ping `.150` z Windows **FAIL** (nested Hyper-V — oczekiwane); klucz WSL `/home/aions/.ssh/aions_milestone_c_key` + `/tmp/aions_mc_key` na Proxmox)
- **Sloppix** — nie istnieje jako forkowalny projekt (patrz niżej)

### Sloppix — fakty (tylko sprawdzone)

| Fakt | Wartość |
|------|---------|
| Oficjalna strona projektu | **Brak** — tylko artykuł Learn Linux TV |
| URL treści | https://www.learnlinux.tv/meet-sloppix-the-new-ai-powered-linux-distro/ |
| Data publikacji | **2026-04-01** |
| GitHub LearnLinuxTV / Sloppix | **Brak** repozytorium Sloppix (11 public repos, żaden Sloppix) |
| ISO / download dystrybucji | **Brak** publicznego ISO |
| Pełne źródło publiczne | **Nie** — to materiał wideo / Patreon early access + limitowana koszulka (learnlinux.link) |
| LICENSE (MIT/Apache/GPL) | **Brak** — nie ma projektu open-source do licencjonowania |
| davidklassen/slopix na GitHub | **Inny projekt** (bare-metal AArch64 kernel, inna nazwa) — **nie** Learn Linux TV Sloppix |

**Wniosek prawny:** copy-modify Sloppix → **NO** (brak źródła i licencji).  
**Rekomendacja:** **ideas-only** — pętla Observe→Plan→Act→Verify→Remember i „AI w terminalu” jako inspiracja; **fork Sloppix = nie**.

### Mapa celów (skrót)

| Cel | Status | ~% |
|-----|--------|-----|
| A. Core = manager | **NEAR** | 55% |
| B. Węzły jako zasoby | **FAR→NEAR** | 32% |
| C. install → rejestracja Node | **FAR** | 50% |
| D. Multi-worker orchestration | **FAR** | 18% |
| E. O→P→A→V→R loop | **NEAR** | 50% |
| F. Własna dystrybucja / Sloppix | **NEAR** (AIONS Image) / Sloppix **N/A** | 70% / 0% |
| G. Operator Senses | **NEAR** | 70% |
| H. CBMS / memory / blends / CP | **NEAR** | 75% |

### Następne 3 kroki

1. **M1 Dysk D: ≥10 GB** — odblokuj mirror i dev; zapisz `runtime/docs/m1_disk_2026-07.json`.
2. **Spec Fazy 6 (minimal):** `install_aions_node.sh` + rejestr capabilities w Core (JSON + health ping) — bez Sloppix, na bazie `install_aions_host.sh`.
3. **Domknij Operator Senses:** Gmail YELLOW→GREEN + orchestrator smoke „co mam jutro?” z kalendarzem (M5 artefakt).

---

## SEKCJA 2 — MASZYNA (gap matrix)

```json
{
  "meta": {
    "generated_at": "2026-07-12",
    "canonical_root": "E:\\server wiedzy",
    "active_phase_agents_md": "Operator Senses (Fala 5)",
    "active_phase_roadmap_v16": "Operator Senses",
    "overall_manager_nodes_stack_pct": 48,
    "sloppix_verdict": "NO_FORK",
    "sloppix_recommendation": "ideas_only"
  },
  "sloppix_facts": {
    "official_project_site": null,
    "content_url": "https://www.learnlinux.tv/meet-sloppix-the-new-ai-powered-linux-distro/",
    "published_date": "2026-04-01",
    "github_learnlinuxtv_sloppix_repo": false,
    "public_iso_download": false,
    "full_source_public": false,
    "license": "none_identified",
    "unrelated_repo_warning": "github.com/davidklassen/slopix — different project, different spelling",
    "legal_copy_modify": "NO",
    "why": "no_public_source_no_license_not_an_oss_distribution_project"
  },
  "goals": [
    {
      "id": "A",
      "goal": "AIONS Core = manager (planner, memory, MCP, task queue, scheduler, node registry, knowledge)",
      "status": "NEAR",
      "pct": 60,
      "evidence": [
        "control_plane/planner.py",
        "control_plane/executor.py",
        "control_plane/scheduler.py",
        "control_plane/api.py",
        "control_plane/orchestrator_loop.py",
        "control_plane/cbms_gate.py",
        "control_plane/node_registry.py",
        "mcpServers/VS_CODE_MCP_CODEX/src/server.py (61 MCP tools)",
        ".claude/specs/AIONS_OS_ROADMAP.md Faza 3 MVP 60%"
      ],
      "missing": [
        "central_persisted_task_queue",
        "cross_host_node_dispatch",
        "unified_core_api_single_brain",
        "control_plane untracked modules not fully in git hygiene"
      ]
    },
    {
      "id": "B",
      "goal": "Nodes as resources (capabilities, health, load, permissions) — not computers",
      "status": "FAR",
      "pct": 32,
      "evidence": [
        "control_plane/node_registry.py",
        "runtime/node/schema.json",
        "runtime/state/node_registry.json",
        "control_plane/api.py /v1/nodes",
        "control_plane/node_dispatch.py",
        "POST /v1/nodes/{id}/dispatch",
        "scripts/test_node_registry.py",
        "scripts/aions_node_heartbeat.py",
        "scripts/aions_node_heartbeat.ps1",
        "runtime/node/aions-node-heartbeat.service.example",
        "runtime/state/node_registry.json includes proxmox-9100 (2026-07-12)",
        "heartbeat OK windows-primary + proxmox-9100 (2026-07-12 PM)",
        "live SSH jump PASS .220→ubuntu@.150 hostname aions (2026-07-12 PM, VM9100 was stopped)",
        "mcpServers/.../provider_registry.py desktop_capabilities (local only)",
        ".claude/specs/AIONS_OS_ROADMAP.md Faza 6 MVP scaffolding"
      ],
      "missing": [
        "aions_node_status",
        "capabilities_registry_per_node",
        "load_balancing",
        "permission_model_per_node",
        "node_abstraction_layer",
        "cross_host_heartbeat_e2e"
      ]
    },
    {
      "id": "C",
      "goal": "install script Ubuntu → AIONS Node registers with Core",
      "status": "FAR",
      "pct": 50,
      "evidence": [
        "runtime/host/install_aions_host.sh",
        "runtime/host/install_aions_node.sh",
        "runtime/docs/PLATFORM_MATRIX.md Hyper-V+Proxmox PASS",
        "runtime/host/validate_install.sh GREEN",
        "POST /v1/nodes/register",
        "scripts/aions_node_heartbeat.py (local smoke OK 2026-07-12)"
      ],
      "missing": [
        "post_install_enroll_e2e_on_proxmox_guest",
        "systemd_timer_prod_deploy",
        "automatic_node_id_from_core"
      ]
    },
    {
      "id": "D",
      "goal": "Multi-worker orchestration (laptop/VM/docker)",
      "status": "FAR",
      "pct": 18,
      "evidence": [
        "control_plane/orchestrator_loop.py --mcp-smoke",
        "control_plane/node_dispatch.py (local OK, remote stub)",
        "POST /v1/nodes/{id}/dispatch smoke OK 2026-07-12",
        "runtime/docs/orchestrator_smoke.json (LOCAL_DEV_PLAN)",
        "MCP aions_plan/aions_execute_step/aions_execution_status"
      ],
      "missing": [
        "worker_pool",
        "cross_host_task_dispatch",
        "docker_worker_nodes",
        "Task Scheduler / systemd timer integration for workers",
        "Faza 6 implementation"
      ]
    },
    {
      "id": "E",
      "goal": "Observe→Plan→Act→Verify→Remember loop (Sloppix Omega style)",
      "status": "NEAR",
      "pct": 50,
      "evidence": [
        "control_plane/orchestrator_loop.py (understand→CBMS gate→speak→memory_store)",
        "MCP think_start/think_step/think_finish",
        "scripts/test_control_plane.py smoke"
      ],
      "missing": [
        "explicit_verify_step",
        "closed_loop_retry_on_verify_fail",
        "omega_style_sysadmin_automation",
        "integration with node workers"
      ]
    },
    {
      "id": "F",
      "goal": "Own Linux distro / Sloppix fork",
      "status": "NEAR_AIONS_IMAGE",
      "pct": 70,
      "evidence": [
        "runtime/host/packer/build_image.ps1 PASS qcow2",
        "runtime/docs/PLATFORM_MATRIX.md AIONS Image PASS",
        "runtime/identity/ AIONS branding",
        ".claude/specs/AIONS_OS_ROADMAP.md Faza 8 75%"
      ],
      "missing": [
        "ISO/bare metal (Faza 8 TODO)",
        "sloppix_fork_impossible_no_source",
        "appliance_wizard Faza 9 0%"
      ],
      "sloppix_subgoal": {
        "status": "NOT_APPLICABLE",
        "pct": 0,
        "note": "Sloppix is video/marketing content without OSS distro; use AIONS Image path instead"
      }
    },
    {
      "id": "G",
      "goal": "Operator Senses (calendar/email)",
      "status": "NEAR",
      "pct": 70,
      "evidence": [
        "runtime/docs/OPERATOR_SENSES_STATUS.md Calendar GREEN",
        "runtime/docs/AI_HANDOFF_OPERATOR_SENSES_2026-07-12.json",
        "MCP calendar_get_events",
        "scripts/calendar_e2e_smoke.py PASS"
      ],
      "missing": [
        "Gmail YELLOW → GREEN E2E",
        "Outlook STUB",
        "M5 orchestrator smoke co mam jutro artifact",
        "AGENTS.md still says no live E2E without creds (stale vs Calendar GREEN)"
      ]
    },
    {
      "id": "H",
      "goal": "CBMS/memory/blends/checkpoints",
      "status": "NEAR",
      "pct": 75,
      "evidence": [
        "aions_core/memory/blends/ seed+conclusions",
        "control_plane/blends/*",
        ".cursor/rules/aions-session-checkpoints.mdc",
        "MCP memory_store/memory_recall",
        "aions_core 545+ chunks (ROADMAP Faza 1)"
      ],
      "missing": [
        "M6 blend→Chroma PASS artifact (LOCAL_DEV_PLAN)",
        "automated blend ingest pipeline closed",
        "sync_scheduler Fala 6 ~40% only"
      ]
    }
  ],
  "blockers": [
    {
      "id": "M1_DISK",
      "severity": "high",
      "evidence": "runtime/docs/LOCAL_DEV_PLAN_2026-07-11.md D: ~29 MB free",
      "impact": "sync_dev_mirror, HV, dev mirror cascade SKIPPED"
    },
    {
      "id": "FAZA6_ZERO",
      "severity": "medium",
      "evidence": "Faza 6 MVP ~32% — VM9100 była stopped (qm start naprawił); live SSH jump PASS .220→ubuntu@.150; ping .150 z Windows FAIL (nested Hyper-V); guest agent not running",
      "impact": "cross-host dispatch: jump SSH OK gdy VM9100 running; Windows nie widzi .150 L2; trzymaj klucz na Proxmox /tmp/aions_mc_key; enroll guest agent + systemd heartbeat następny krok"
    },
    {
      "id": "HV_CURRENT_FAIL",
      "severity": "medium",
      "evidence": "runtime/docs/PLATFORM_MATRIX.md VM Off 2026-07-11",
      "impact": "local worker target unavailable without LAN cable"
    }
  ],
  "control_plane_inventory": [
    "control_plane/__init__.py",
    "control_plane/api.py",
    "control_plane/cbms_gate.py",
    "control_plane/executor.py",
    "control_plane/llm_adapter.py",
    "control_plane/models.py",
    "control_plane/node_dispatch.py",
    "control_plane/node_registry.py",
    "control_plane/orchestrator_loop.py",
    "control_plane/planner.py",
    "control_plane/policy.py",
    "control_plane/scheduler.py",
    "control_plane/blends/analyze_blend.py",
    "control_plane/blends/search_blends.py",
    "control_plane/blends/write_conclusion.py"
  ],
  "roadmap_phase_table": {
    "1_Core_Runtime": "100% closed",
    "2_Deploy_Anywhere": "67% closed 2/3 VPS SKIPPED",
    "3_AI_Control_Plane": "60% MVP",
    "4_AIONS_Identity": "70%",
    "5_Local_Intelligence": "0%",
    "6_Distributed_AIONS": "32% MVP + proxmox-9100 + live SSH jump PASS",
    "7_Autonomous_Infrastructure": "25%",
    "8_AIONS_Image": "75%",
    "9_Appliance": "0%",
    "10_Ecosystem": "0%"
  }
}
```

---

## Changelog

| Data | Zmiana |
|------|--------|
| 2026-07-12 PM (2) | Diagnostyka: VM9100 stopped→`qm start`; live SSH jump PASS `.220→ubuntu@.150`; ping Windows→.150 FAIL (nested); Faza 6 30%→32%, overall 47%→48% |
| 2026-07-12 PM | Heartbeat oba węzły OK; dispatch stub (`node_dispatch.py`, POST /v1/nodes/{id}/dispatch); SSH jump FAIL; Faza 6 25%→30%, overall 45%→47% |
| 2026-07-12 | Proxmox: przerwano SSH rabbit hole; fakty z pamięci+matrix (PASS `.220`/`.150`/9100); zarejestrowano `proxmox-9100` w lokalnym Core; Faza 6 22%→25%, overall 44%→45% |
| 2026-07-12 | Heartbeat client: aions_node_heartbeat.py/ps1, systemd example; local smoke OK; Proxmox enroll SKIPPED (SSH key 0777); Faza 6 15%→22%, overall 42%→44% |
| 2026-07-12 | Faza 6 MVP: node_registry, /v1/nodes API, install_aions_node.sh, planner node_id |
| 2026-07-12 | Pierwsza analiza odległości od celów strategii Marcina + Sloppix fact-check |

*Plik w `runtime/docs/` — nie commitować bez prośby Marcina.*
