#!/usr/bin/env bash
set -eu
RUN_SCRIPT="${1:?run script on guest}"
REPO_TGZ="${2:-/tmp/aions-repo.tgz}"
STAGING="${3:-/tmp/aions-repo}"

fix_guest_dns() {
  if [[ -L /etc/resolv.conf ]] && grep -q '127.0.0.53' /etc/resolv.conf 2>/dev/null; then
    sudo rm -f /etc/resolv.conf
    printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' | sudo tee /etc/resolv.conf >/dev/null
  elif ! getent hosts archive.ubuntu.com >/dev/null 2>&1; then
    printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' | sudo tee /etc/resolv.conf >/dev/null 2>/dev/null || true
  fi
}
fix_guest_dns

sudo mkdir -p "${STAGING}" /var/log/aions/milestone-c
if [[ -f "${REPO_TGZ}" ]]; then
  sudo tar -xzf "${REPO_TGZ}" -C "${STAGING}"
  if [[ -d "${STAGING}/server-wiedzy" ]]; then
    sudo rm -rf /tmp/server-wiedzy-extract
    sudo mv "${STAGING}/server-wiedzy" /tmp/server-wiedzy-extract
    sudo rm -rf "${STAGING}"
    sudo mv /tmp/server-wiedzy-extract "${STAGING}"
  elif [[ -d /tmp/server-wiedzy ]]; then
    sudo rm -rf "${STAGING}"
    sudo mv /tmp/server-wiedzy "${STAGING}"
  fi
fi
[[ -d "${STAGING}/runtime/host" ]] || { echo "ERROR: brak repo w ${STAGING}"; exit 1; }
sudo find "${STAGING}" -type f \( -name '*.sh' -o -name '*.yaml' -o -name '*.yml' \) -exec sed -i 's/\r$//' {} + 2>/dev/null || true

export REPO_SRC="${STAGING}"
export LOG_DIR=/var/log/aions/milestone-c
export PIP_CACHE_DIR=/var/lib/aions/pip-cache
export TMPDIR=/tmp TMP=/tmp TEMP=/tmp
sudo mkdir -p "${PIP_CACHE_DIR}"
chmod +x "${RUN_SCRIPT}"
sudo bash "${RUN_SCRIPT}"
