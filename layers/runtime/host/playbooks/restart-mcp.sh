#!/usr/bin/env bash
# Restart MCP service after health failure.
set -euo pipefail
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u aions)}"
/opt/aions/repo/scripts/aions-ctl mcp-stop 2>/dev/null || true
sleep 2
/opt/aions/repo/scripts/aions-ctl mcp-start
echo "[playbook] mcp restarted"
