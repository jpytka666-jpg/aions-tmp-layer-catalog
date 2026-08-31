#!/usr/bin/env bash
# Resume Milestone C on existing Proxmox VM (skip VM create, use /tmp repo tarball).
export SKIP_VM_CREATE=1
export PROXMOX_HOST=root@192.168.1.220
export PROXMOX_STORAGE=local-lvm
export LOG_DIR=/mnt/d/AIONS_DEV/logs/milestone-c-proxmox
export REPO_ROOT='/mnt/e/server wiedzy'
export PRIV_KEY=/mnt/d/AIONS_DEV/vm/aions-milestone-c/keys/id_ed25519
export PUB_KEY=/mnt/d/AIONS_DEV/vm/aions-milestone-c/keys/id_ed25519.pub
export REPO_TGZ=/tmp/aions-repo.tgz
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/run_milestone_c_proxmox.sh"
