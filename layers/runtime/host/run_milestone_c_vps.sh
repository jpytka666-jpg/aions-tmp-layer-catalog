#!/usr/bin/env bash
# Milestone C on generic VPS (public cloud) — same guest flow as Hyper-V continue.
set -euo pipefail

VPS_IP="${VPS_IP:-}"
LOG_DIR="${LOG_DIR:-/mnt/d/AIONS_DEV/logs/milestone-c-vps}"
REPO_ROOT="${REPO_ROOT:-/mnt/e/server wiedzy}"
PRIV_KEY="${PRIV_KEY:-/mnt/d/AIONS_DEV/vm/aions-milestone-c/keys/id_ed25519}"
GUEST_USER="${GUEST_USER:-ubuntu}"

if [[ -z "${VPS_IP}" && -f "${LOG_DIR}/vps.env" ]]; then
  # shellcheck source=/dev/null
  source "${LOG_DIR}/vps.env"
fi
[[ -n "${VPS_IP}" ]] || { echo "Ustaw VPS_IP lub utworz ${LOG_DIR}/vps.env"; exit 1; }

log() { echo "[$(date -Iseconds)][VPS] $*" | tee -a "${LOG_DIR}/host.log"; }

mkdir -p "${LOG_DIR}"
log "Milestone C VPS IP=${VPS_IP}"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File \
  "E:/server wiedzy/runtime/host/continue_milestone_c_vps.ps1" -Ip "${VPS_IP}"
