#!/usr/bin/env bash
# Install AIONS identity files (Faza 4) — run from install_aions_host or cloud-init.
set -euo pipefail
IDENTITY_DIR="${1:-/opt/aions/repo/runtime/identity}"
[[ -d "${IDENTITY_DIR}" ]] || exit 0

hostnamectl set-hostname aions 2>/dev/null || echo aions > /etc/hostname

if [[ -f "${IDENTITY_DIR}/issue.aions" ]]; then
  cp "${IDENTITY_DIR}/issue.aions" /etc/issue
  cp "${IDENTITY_DIR}/issue.aions" /etc/issue.net
fi

if [[ -f "${IDENTITY_DIR}/motd.aions" ]]; then
  install -m 0755 "${IDENTITY_DIR}/motd.aions" /etc/update-motd.d/99-aions
  chmod +x /etc/update-motd.d/99-aions
fi

if [[ -f "${IDENTITY_DIR}/profile.d-aions.sh" ]]; then
  install -m 0644 "${IDENTITY_DIR}/profile.d-aions.sh" /etc/profile.d/aions.sh
fi

if [[ -f "${IDENTITY_DIR}/aions-boot-status.service" ]]; then
  install -m 0644 "${IDENTITY_DIR}/aions-boot-status.service" /etc/systemd/system/aions-boot-status.service
  systemctl daemon-reload
  systemctl enable aions-boot-status.service
fi

echo "[AIONS][identity] installed"
