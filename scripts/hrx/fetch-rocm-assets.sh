#!/usr/bin/env bash
set -euo pipefail

HRX_SRC_DIR="${HRX_SRC_DIR:-${RUNNER_TEMP:-/tmp}/hrx-src}"
HRX_ROCM_ROOT="${HRX_ROCM_ROOT:-${RUNNER_TEMP:-/tmp}/hrx-rocm-root}"
HRX_DOWNLOAD_CACHE_DIR="${HRX_DOWNLOAD_CACHE_DIR:-${RUNNER_TEMP:-/tmp}/hrx-rocm-downloads}"
HRX_RELEASE_TYPE="${HRX_RELEASE_TYPE:-nightly}"
HRX_RUN_ID="${HRX_RUN_ID:-}"
HRX_ARTIFACT_SET="${HRX_ARTIFACT_SET:-core-with-upstream-hip}"

export HRX_ROCM_ROOT HRX_DOWNLOAD_CACHE_DIR HRX_RELEASE_TYPE HRX_RUN_ID HRX_ARTIFACT_SET

python3 "${HRX_SRC_DIR}/build_tools/ci_core_linux.py" fetch-rocm

export ROCM_PATH="${HRX_ROCM_ROOT}"
export CMAKE_PREFIX_PATH="${HRX_ROCM_ROOT}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
export PATH="${HRX_ROCM_ROOT}/lib/llvm/bin:${HRX_ROCM_ROOT}/bin:${PATH}"
export LD_LIBRARY_PATH="${HRX_ROCM_ROOT}/lib:${HRX_ROCM_ROOT}/lib/rocm_sysdeps/lib:${LD_LIBRARY_PATH:-}"

"${HRX_ROCM_ROOT}/lib/llvm/bin/amdclang" --version
"${HRX_ROCM_ROOT}/lib/llvm/bin/amdclang++" --version
