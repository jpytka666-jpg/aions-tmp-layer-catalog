#!/usr/bin/env bash
# Daily backup snapshot — chroma + cbms state (Faza 7 minimal slice).
set -euo pipefail
DEST="${AIONS_STATE_ROOT:-/var/lib/aions}/backups"
STAMP="$(date +%Y%m%d_%H%M%S)"
mkdir -p "${DEST}"
tar -czf "${DEST}/aions-data-${STAMP}.tar.gz" \
  -C "${AIONS_STATE_ROOT:-/var/lib/aions}" data 2>/dev/null || true
find "${DEST}" -name 'aions-data-*.tar.gz' -mtime +7 -delete 2>/dev/null || true
echo "[backup] ${DEST}/aions-data-${STAMP}.tar.gz"
