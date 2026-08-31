#!/usr/bin/env bash
# AIONS Node Installer — Faza 6 MVP stub (Ubuntu-oriented)
#
# Installs minimal deps, probes Core HTTP API, registers node or writes local file.
#
# Usage:
#   sudo ./install_aions_node.sh [OPTIONS]
#
# Options:
#   --node-id ID           Node id (default: hostname-based)
#   --core-url URL         Core API base (default: AIONS_CORE_URL or http://127.0.0.1:8765)
#   --capabilities LIST    Comma-separated capabilities (default: mcp,shell,cbms)
#   --tools LIST           Comma-separated tools (default: system_health,fast_search)
#   --memory-mb N          Reported RAM MB (default: auto from /proc/meminfo)
#   --state-dir PATH       Local registration fallback dir (default: /var/lib/aions)
#   --dry-run              Print actions only
#   -h, --help             Help
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
NODE_ID="${AIONS_NODE_ID:-}"
CORE_URL="${AIONS_CORE_URL:-http://127.0.0.1:8765}"
CAPABILITIES="${AIONS_NODE_CAPABILITIES:-mcp,shell,cbms}"
TOOLS="${AIONS_NODE_TOOLS:-system_health,fast_search,memory_recall,cbms_search}"
MEMORY_MB="${AIONS_NODE_MEMORY_MB:-0}"
STATE_DIR="${AIONS_STATE_DIR:-/var/lib/aions}"
PERMISSIONS="${AIONS_NODE_PERMISSIONS:-execute,read}"

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

log() { echo "[AIONS][node-install] $*"; }
die() { echo "[AIONS][node-install][ERROR] $*" >&2; exit 1; }

run() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --node-id) NODE_ID="$2"; shift 2 ;;
      --core-url) CORE_URL="$2"; shift 2 ;;
      --capabilities) CAPABILITIES="$2"; shift 2 ;;
      --tools) TOOLS="$2"; shift 2 ;;
      --memory-mb) MEMORY_MB="$2"; shift 2 ;;
      --state-dir) STATE_DIR="$2"; shift 2 ;;
      --dry-run) DRY_RUN=true; shift ;;
      -h|--help) usage 0 ;;
      *) die "Unknown arg: $1 (use -h)" ;;
    esac
  done
}

detect_memory_mb() {
  if [[ "${MEMORY_MB}" != "0" && -n "${MEMORY_MB}" ]]; then
    return
  fi
  if [[ -r /proc/meminfo ]]; then
    local kb
    kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
    MEMORY_MB=$(( kb / 1024 ))
  else
    MEMORY_MB=4096
  fi
}

detect_host() {
  hostname -f 2>/dev/null || hostname 2>/dev/null || echo "localhost"
}

default_node_id() {
  local h
  h="$(detect_host | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-')"
  echo "node-${h}"
}

install_deps() {
  log "Installing placeholder deps (curl, ca-certificates)..."
  if command -v apt-get >/dev/null 2>&1; then
    run apt-get update -qq || true
    run apt-get install -y -qq curl ca-certificates jq python3 python3-venv || true
  elif command -v dnf >/dev/null 2>&1; then
    run dnf install -y curl ca-certificates jq python3 || true
  else
    log "No apt/dnf — skipping package install (curl must exist for Core register)"
  fi
}

json_array_from_csv() {
  local csv="$1"
  local IFS=','
  read -ra parts <<< "${csv}"
  local out="["
  local first=true
  for p in "${parts[@]}"; do
    p="$(echo "${p}" | xargs)"
    [[ -z "${p}" ]] && continue
    if [[ "${first}" == "true" ]]; then first=false; else out+=","; fi
    out+="\"${p}\""
  done
  out+="]"
  echo "${out}"
}

build_payload() {
  local host caps tools perms
  host="$(detect_host)"
  caps="$(json_array_from_csv "${CAPABILITIES}")"
  tools="$(json_array_from_csv "${TOOLS}")"
  perms="$(json_array_from_csv "${PERMISSIONS}")"
  cat <<EOF
{
  "node_id": "${NODE_ID}",
  "host": "${host}",
  "capabilities": ${caps},
  "memory_mb": ${MEMORY_MB},
  "tools": ${tools},
  "health": "ok",
  "load": 0.0,
  "permissions": ${perms}
}
EOF
}

register_via_core() {
  local payload url
  payload="$(build_payload)"
  url="${CORE_URL%/}/v1/nodes/register"
  log "Registering with Core: ${url}"
  if ! command -v curl >/dev/null 2>&1; then
    log "curl missing — falling back to local file"
    return 1
  fi
  local http_code body tmp
  tmp="$(mktemp)"
  http_code="$(curl -sS -o "${tmp}" -w '%{http_code}' \
    -X POST "${url}" \
    -H "Content-Type: application/json" \
    -d "${payload}" \
    --connect-timeout 5 \
    --max-time 15 || echo "000")"
  body="$(cat "${tmp}")"
  rm -f "${tmp}"
  if [[ "${http_code}" =~ ^2 ]]; then
    log "Core registration OK (${http_code}): ${body}"
    return 0
  fi
  log "Core registration failed (HTTP ${http_code}): ${body}"
  return 1
}

write_local_registration() {
  local dest payload
  payload="$(build_payload)"
  dest="${STATE_DIR}/node_registration.json"
  log "Writing local registration: ${dest}"
  run mkdir -p "${STATE_DIR}"
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY-RUN] write ${dest}"
    echo "${payload}"
  else
    printf '%s\n' "${payload}" > "${dest}"
    chmod 644 "${dest}" 2>/dev/null || true
  fi
}

main() {
  parse_args "$@"
  [[ -n "${NODE_ID}" ]] || NODE_ID="$(default_node_id)"
  detect_memory_mb
  log "node_id=${NODE_ID} core=${CORE_URL} memory_mb=${MEMORY_MB}"
  install_deps
  if register_via_core; then
    log "Node enrolled with Core."
  else
    write_local_registration
    log "Core unreachable — local registration file written."
    log "When Core is up: curl -X POST ${CORE_URL%/}/v1/nodes/register -d @${STATE_DIR}/node_registration.json -H Content-Type:application/json"
  fi
  log "Done."
}

main "$@"
