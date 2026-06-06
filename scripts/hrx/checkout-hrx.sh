#!/usr/bin/env bash
set -euo pipefail

HRX_REPOSITORY="${HRX_REPOSITORY:-https://github.com/ROCm/hrx.git}"
HRX_REF="${HRX_REF:-}"
HRX_SRC_DIR="${HRX_SRC_DIR:-${RUNNER_TEMP:-/tmp}/hrx-src}"

if [[ -d "${HRX_SRC_DIR}/.git" ]]; then
    git -C "${HRX_SRC_DIR}" remote set-url origin "${HRX_REPOSITORY}"
    git -C "${HRX_SRC_DIR}" fetch --prune origin
else
    mkdir -p "$(dirname "${HRX_SRC_DIR}")"
    if [[ -z "${HRX_REF}" ]]; then
        git clone --depth=1 "${HRX_REPOSITORY}" "${HRX_SRC_DIR}"
    else
        git clone "${HRX_REPOSITORY}" "${HRX_SRC_DIR}"
    fi
fi

if [[ -n "${HRX_REF}" ]]; then
    git -C "${HRX_SRC_DIR}" fetch origin "${HRX_REF}" --depth=1 || true
    git -C "${HRX_SRC_DIR}" checkout --detach FETCH_HEAD 2>/dev/null || \
        git -C "${HRX_SRC_DIR}" checkout "${HRX_REF}"
fi

git -C "${HRX_SRC_DIR}" rev-parse HEAD
