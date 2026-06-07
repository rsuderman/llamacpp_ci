#!/usr/bin/env bash

# Shared environment defaults for local build entrypoints.
# Expects REPO_ROOT to be pre-set by the caller.

: "${HRX_WORK_DIR:=${REPO_ROOT}}"
: "${HRX_SRC_DIR:=${HRX_WORK_DIR}/assets/hrx-src}"
: "${HRX_ROCM_ROOT:=${HRX_WORK_DIR}/assets/hrx-rocm-root}"
: "${HRX_DOWNLOAD_CACHE_DIR:=${HRX_WORK_DIR}/assets/hrx-rocm-downloads}"
: "${HRX_BUILD_DIR:=${HRX_WORK_DIR}/build-hrx}"
: "${HRX_INSTALL_PREFIX:=${HRX_WORK_DIR}/build-hrx-install}"

: "${LLAMA_SRC_DIR:=${HRX_WORK_DIR}/assets/llama-src}"
: "${LLAMA_BUILD_DIR:=${LLAMA_SRC_DIR}/build-hrx}"

export HRX_WORK_DIR
export HRX_SRC_DIR HRX_ROCM_ROOT HRX_DOWNLOAD_CACHE_DIR
export HRX_BUILD_DIR HRX_INSTALL_PREFIX
export LLAMA_SRC_DIR LLAMA_BUILD_DIR
