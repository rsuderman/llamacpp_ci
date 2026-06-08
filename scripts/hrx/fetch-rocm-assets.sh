#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

. "${SCRIPT_DIR}/env.sh"

python3 "${SCRIPT_DIR}/fetch-rocm-assets.py"

export ROCM_PATH="${HRX_ROCM_ROOT}"
export CMAKE_PREFIX_PATH="${HRX_ROCM_ROOT}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
export PATH="${HRX_ROCM_ROOT}/lib/llvm/bin:${HRX_ROCM_ROOT}/bin:${PATH}"
export LD_LIBRARY_PATH="${HRX_ROCM_ROOT}/lib:${HRX_ROCM_ROOT}/lib/rocm_sysdeps/lib:${LD_LIBRARY_PATH:-}"

if [[ -n "${GITHUB_ENV:-}" ]]; then
    {
        echo "ROCM_PATH=${ROCM_PATH}"
        echo "CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH}"
        echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"
    } >>"${GITHUB_ENV}"
fi

if [[ -n "${GITHUB_PATH:-}" ]]; then
    {
        echo "${HRX_ROCM_ROOT}/lib/llvm/bin"
        echo "${HRX_ROCM_ROOT}/bin"
    } >>"${GITHUB_PATH}"
fi

"${HRX_ROCM_ROOT}/lib/llvm/bin/amdclang" --version
"${HRX_ROCM_ROOT}/lib/llvm/bin/amdclang++" --version
