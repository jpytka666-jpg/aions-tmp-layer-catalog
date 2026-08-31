#!/usr/bin/env bash
# Backward-compatible wrapper — use guest_milestone_c_run.sh for new platforms.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/guest_milestone_c_run.sh" "$@"
