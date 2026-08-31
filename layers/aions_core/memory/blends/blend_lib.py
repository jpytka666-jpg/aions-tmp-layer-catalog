"""AIONS Blend Learning — offline mistake → analyzer → conclusion pipeline."""

from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

BLEND_DIR = Path(__file__).resolve().parent
SEED_DIR = BLEND_DIR / "seed"
CONCLUSIONS_DIR = BLEND_DIR / "conclusions"
MISTAKES_DIR = BLEND_DIR / "mistakes"
MANIFEST_PATH = BLEND_DIR / "blend_manifest.json"
SCHEMA_PATH = BLEND_DIR / "blend_schema.json"

DOMAIN_ERROR_CLASS: dict[str, str] = {
    "proxmox": "missing_caveat",
    "oauth": "credential_assumption",
    "disk": "disk_misconception",
    "git": "imprecise_metric",
    "hyperv": "status_conflation",
}

ERROR_CLASS_RULES: list[tuple[str, str, list[str]]] = [
    (
        r"jump|SSH|\.150|Windows.*ping|brak trasy",
        "missing_caveat",
        ["PASS bez opisu ścieżki dostępu jest niepełny"],
    ),
    (
        r"OAuth|credentials|REAL|token|client_id|secret",
        "credential_assumption",
        ["REAL wymaga zweryfikowanych credentiali, nie samej konfiguracji"],
    ),
    (
        r"AVHDX|VHDX|30\s*GB|merge|consolidat|wolne.*D:",
        "disk_misconception",
        ["Merge AVHDX ≠ zwolnienie miejsca na dysku hosta"],
    ),
    (
        r"dirty|untracked|git status|~90|control_plane",
        "imprecise_metric",
        ["Podawaj dokładne liczby i zakres plików z git status"],
    ),
    (
        r"PARTIAL_FAIL|PARTIAL FAIL|całkowity FAIL|total FAIL|zlał.*sukces",
        "status_conflation",
        ["Rozróżnij PARTIAL_FAIL od FAIL i PASS od PASS z caveat"],
    ),
]


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_schema() -> dict[str, Any]:
    with SCHEMA_PATH.open(encoding="utf-8") as fh:
        return json.load(fh)


def load_blend(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def save_blend(blend: dict[str, Any], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    blend["updated"] = _now_iso()
    with path.open("w", encoding="utf-8") as fh:
        json.dump(blend, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def _classify_error(text: str, domain: str = "") -> tuple[str, list[str]]:
    combined = text.lower()
    if domain in DOMAIN_ERROR_CLASS:
        ec = DOMAIN_ERROR_CLASS[domain]
        for pattern, error_class, patterns in ERROR_CLASS_RULES:
            if error_class == ec and re.search(pattern, text, re.IGNORECASE):
                return error_class, patterns
        return ec, [f"Domena {domain} — sprawdź blend seed przed claimem"]
    for pattern, error_class, patterns in ERROR_CLASS_RULES:
        if re.search(pattern, text, re.IGNORECASE):
            return error_class, patterns
    if "assume" in combined or "expect" in combined:
        return "unverified_claim", ["Zweryfikuj twierdzenie narzędziem, nie z pamięci"]
    return "other", ["Sprawdź źródło przed powtórzeniem twierdzenia"]


def analyze_mistake(blend: dict[str, Any]) -> dict[str, Any]:
    """Deterministic offline analyzer — no LLM, no network."""
    mistake = blend.get("mistake", {})
    claim = mistake.get("claim", "")
    happened = mistake.get("what_happened", "")
    domain = blend.get("domain", "")
    tags = " ".join(blend.get("tags", []))
    corpus = f"{claim} {happened} {domain} {tags}"

    error_class, patterns = _classify_error(corpus, domain=domain)
    root_causes = {
        "status_conflation": (
            "Agent zlał różne poziomy sukcesu (PARTIAL vs FAIL, PASS bez warunków)."
        ),
        "missing_caveat": (
            "Wynik PASS opisany bez ścieżki dostępu (jump host, brak trasy z Windows)."
        ),
        "credential_assumption": (
            "Status REAL/WORKING przypisany bez obecności credentiali w środowisku."
        ),
        "disk_misconception": (
            "Merge AVHDX konsoliduje łańcuch differencing — nie zwalnia miejsca na D:."
        ),
        "imprecise_metric": (
            "Metryka git (~90 dirty) podana bez zakresu (które pliki, staged vs unstaged)."
        ),
        "unverified_claim": "Twierdzenie bez dowodu z narzędzia lub logu sesji.",
        "other": "Błąd wymaga ręcznej klasyfikacji po weryfikacji.",
    }

    blend["analyzer"] = {
        "root_cause": root_causes.get(error_class, root_causes["other"]),
        "error_class": error_class,
        "patterns": patterns,
        "analyzed_at": _now_iso(),
    }
    blend["status"] = "analyzed"
    return blend


def write_conclusion(blend: dict[str, Any]) -> dict[str, Any]:
    """Derive actionable conclusion from analyzer output."""
    if "analyzer" not in blend:
        blend = analyze_mistake(blend)

    analyzer = blend["analyzer"]
    mistake = blend.get("mistake", {})
    error_class = analyzer.get("error_class", "other")
    domain = blend.get("domain", "general")

    rules: dict[str, str] = {
        "status_conflation": (
            "PARTIAL_FAIL = część kroków OK, blocker nadal aktywny. "
            "Nie raportuj jako pełny FAIL ani PASS bez listy co działa / co nie."
        ),
        "missing_caveat": (
            "Proxmox .150 PASS tylko przez jump root@192.168.1.220 → ubuntu@.150. "
            "Z Windows (dev) ping/SSH do .150 = timeout — to nie jest FAIL gościa."
        ),
        "credential_assumption": (
            "Google OAuth: REAL dopiero gdy client_id/secret/token w .env lub vault "
            "i testowy flow zwraca token. Scaffolding ≠ REAL."
        ),
        "disk_misconception": (
            "Merge orphan AVHDX do parent VHDX usuwa plik różnicujący, "
            "ale rozmiar parent rośnie — nie oczekuj ~30 GB wolnego na D:."
        ),
        "imprecise_metric": (
            "Zamiast «dirty~90 / cały control_plane untracked» podaj: "
            "git status --short | wc -l oraz czy chodzi o untracked vs modified."
        ),
        "unverified_claim": "Każde twierdzenie o stanie systemu wymaga outputu narzędzia w tej sesji.",
        "other": "Przed powtórzeniem sprawdź blend_search i cbms_search po tagach domeny.",
    }

    verify_defaults: dict[str, list[str]] = {
        "status_conflation": [
            "Przeczytaj status z artefaktu sesji (PARTIAL_FAIL / PASS / STUB)",
            "Wymień co przeszło i co zablokowane",
        ],
        "missing_caveat": [
            "Sprawdź CONTROL_PLANE_E2E.md — trasa z Windows do .150",
            "Opisz jump host jeśli raportujesz PASS",
        ],
        "credential_assumption": [
            "grep .env / vault — brak secret = nie REAL",
            "Nie planuj flow OAuth bez credentiali",
        ],
        "disk_misconception": [
            "Get-Volume D: przed i po merge — rozmiar parent VHDX",
            "D: full root cause ≠ AVHDX merge fix",
        ],
        "imprecise_metric": [
            "git status --short | measure",
            "Rozdziel modified / untracked / staged",
        ],
        "unverified_claim": ["Uruchom narzędzie w tej sesji", "blend_search przed claimem"],
        "other": ["blend_search", "cbms_search"],
    }

    tags = blend.get("tags", [])
    search_queries = list(
        dict.fromkeys(
            tags
            + [domain, error_class, mistake.get("claim", "")[:40]]
            + analyzer.get("patterns", [])
        )
    )

    blend["conclusion"] = {
        "rule": rules.get(error_class, rules["other"]),
        "verify_before_claim": verify_defaults.get(error_class, verify_defaults["other"]),
        "search_queries": [q for q in search_queries if q],
        "concluded_at": _now_iso(),
    }
    blend["status"] = "concluded"
    return blend


def search_blends(query: str, directory: Optional[Path] = None) -> list[dict[str, Any]]:
    """Offline keyword search across seed + conclusions."""
    base = directory or BLEND_DIR
    hits: list[tuple[int, dict[str, Any], Path]] = []
    q_tokens = [t.lower() for t in re.split(r"\W+", query) if len(t) > 2]

    for folder in (SEED_DIR, CONCLUSIONS_DIR, MISTAKES_DIR):
        if not folder.exists():
            continue
        for path in folder.glob("*.json"):
            blend = load_blend(path)
            blob = json.dumps(blend, ensure_ascii=False).lower()
            score = sum(1 for t in q_tokens if t in blob)
            if score:
                hits.append((score, blend, path))

    hits.sort(key=lambda x: (-x[0], x[2].name))
    return [{"score": s, "path": str(p), "blend": b} for s, b, p in hits]


def export_cbms_chunk(blend: dict[str, Any], chunk_id: Optional[str] = None) -> dict[str, Any]:
    """Build CBMS-ready chunk dict without touching manifest or Chroma."""
    cid = chunk_id or f"KBLEND{blend['id'].replace('BLEND-', '').replace('-', '')[:12].upper()}"
    mistake = blend.get("mistake", {})
    conclusion = blend.get("conclusion", {})
    analyzer = blend.get("analyzer", {})
    content = (
        f"BLEND LEARNING [{blend['id']}]\n"
        f"Domena: {blend.get('domain')}\n"
        f"Błąd: {mistake.get('claim', '')}\n"
        f"Fakty: {mistake.get('what_happened', '')}\n"
        f"Klasa: {analyzer.get('error_class', 'n/a')}\n"
        f"Przyczyna: {analyzer.get('root_cause', '')}\n"
        f"Reguła: {conclusion.get('rule', '')}\n"
        f"Weryfikuj: {'; '.join(conclusion.get('verify_before_claim', []))}"
    )
    return {
        "id": cid,
        "concept": "blend_learning",
        "content": content,
        "created": _now_iso(),
        "size": len(content),
        "references": [str(BLEND_DIR / "seed" / f"{blend['id']}.json")],
        "access_count": 0,
        "last_accessed": None,
    }


def update_manifest(blend: dict[str, Any], path: Path) -> None:
    manifest: dict[str, Any] = {"version": 1, "blends": []}
    if MANIFEST_PATH.exists():
        with MANIFEST_PATH.open(encoding="utf-8") as fh:
            manifest = json.load(fh)

    entry = {
        "id": blend["id"],
        "status": blend.get("status"),
        "domain": blend.get("domain"),
        "path": str(path),
        "error_class": blend.get("analyzer", {}).get("error_class"),
        "updated": blend.get("updated", _now_iso()),
    }
    blends = [b for b in manifest.get("blends", []) if b.get("id") != blend["id"]]
    blends.append(entry)
    manifest["blends"] = sorted(blends, key=lambda x: x["id"])
    manifest["updated"] = _now_iso()
    with MANIFEST_PATH.open("w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
