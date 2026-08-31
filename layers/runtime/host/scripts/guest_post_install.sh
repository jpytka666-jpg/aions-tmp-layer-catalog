#!/usr/bin/env bash
set -eu
RUN_SCRIPT="${1:?run script on guest}"
export REPO_SRC=/opt/aions/repo
export LOG_DIR=/var/log/aions/milestone-c
export TMPDIR=/tmp TMP=/tmp TEMP=/tmp
chmod +x "${RUN_SCRIPT}"
sudo bash "${RUN_SCRIPT}"
