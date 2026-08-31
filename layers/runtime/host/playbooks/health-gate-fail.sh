#!/usr/bin/env bash
# Called when health check fails — attempt service recovery.
set -euo pipefail
LOG="${AIONS_LOG_DIR:-/home/aions/aions/logs}/playbook-health.log"
echo "[$(date -Iseconds)] health gate FAIL — recovery" >> "${LOG}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${DIR}/restart-api.sh" >> "${LOG}" 2>&1 || true
bash "${DIR}/restart-mcp.sh" >> "${LOG}" 2>&1 || true
/opt/aions/repo/scripts/aions-ctl run-health >> "${LOG}" 2>&1 || true
