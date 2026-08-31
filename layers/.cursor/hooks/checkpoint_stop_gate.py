#!/usr/bin/env python3
"""
AIONS stop hook — audit-only checkpoint gate (stdlib; no Chroma/MCP).

Appends a marker to logs/conversation_dumps/checkpoint_stop_audit.jsonl.
Actual memory_store + conv_dump MUST be done by the agent via MCP
(user-aions-context) per .cursor/rules/aions-session-checkpoints.mdc.
"""
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
AUDIT_FILE = REPO_ROOT / "logs" / "conversation_dumps" / "checkpoint_stop_audit.jsonl"
DUMPS_DIR = REPO_ROOT / "logs" / "conversation_dumps"
CHECKPOINT_MARKERS = ("CHECKPOINT", "AUTO_CHECKPOINT")
RECENT_ENTRY_LIMIT = 20

FOLLOWUP = (
    "AIONS STOP GATE: Wykonaj teraz checkpoint sesji na MCP user-aions-context: "
    "(1) memory_store(session_id='claude_marcin_main', text z tagiem [CHECKPOINT] lub "
    "[AUTO_CHECKPOINT] — 2–4 zdania postępu i następnego kroku), "
    "(2) conv_dump(summary=ten sam skrót). To obowiązkowe przed zakończeniem."
)


def _today_autolog_path() -> Path:
    return DUMPS_DIR / f"autolog_{datetime.now().strftime('%Y-%m-%d')}.jsonl"


def _recent_checkpoint_done() -> bool:
    """True if today's autolog tail already contains a checkpoint marker."""
    dump_file = _today_autolog_path()
    if not dump_file.exists():
        return False
    entries: list[dict] = []
    try:
        with open(dump_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        entries.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
    except OSError:
        return False
    for entry in entries[-RECENT_ENTRY_LIMIT:]:
        blob = f"{entry.get('tool', '')} {entry.get('args', '')} {entry.get('result', '')}"
        if any(marker in blob for marker in CHECKPOINT_MARKERS):
            return True
    return False


def _append_audit(hook_input: dict, checkpoint_recent: bool) -> None:
    AUDIT_FILE.parent.mkdir(parents=True, exist_ok=True)
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "event": "stop",
        "hook": "checkpoint_stop_gate",
        "status": hook_input.get("status", "unknown"),
        "checkpoint_recent": checkpoint_recent,
    }
    with open(AUDIT_FILE, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def main() -> int:
    hook_input: dict = {}
    try:
        raw = sys.stdin.read()
        if raw.strip():
            hook_input = json.loads(raw)
    except json.JSONDecodeError:
        pass

    checkpoint_recent = _recent_checkpoint_done()
    _append_audit(hook_input, checkpoint_recent)
    payload: dict = {}
    if not checkpoint_recent:
        payload["followup_message"] = FOLLOWUP
    sys.stdout.write(json.dumps(payload, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
