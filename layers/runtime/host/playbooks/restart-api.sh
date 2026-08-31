#!/usr/bin/env bash
set -euo pipefail
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u aions)}"
systemctl --user restart aions-api.service 2>/dev/null || \
  /opt/aions/repo/scripts/aions-ctl api-stop 2>/dev/null; \
  /opt/aions/repo/scripts/aions-ctl api-start 2>/dev/null || true
echo "[playbook] api restarted"
