#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

. "${SCRIPT_DIR}/env.sh"

CMAKE_COMPILER_LAUNCHER="${CMAKE_COMPILER_LAUNCHER:-}"
if [[ -z "${CMAKE_COMPILER_LAUNCHER}" ]] && command -v ccache >/dev/null 2>&1; then
    CMAKE_COMPILER_LAUNCHER="ccache"
fi

cmake_args=(
    -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}"
    -DCMAKE_INSTALL_PREFIX="${HRX_INSTALL_PREFIX}"
    -DCMAKE_C_COMPILER="${HRX_ROCM_ROOT}/lib/llvm/bin/amdclang"
    -DCMAKE_CXX_COMPILER="${HRX_ROCM_ROOT}/lib/llvm/bin/amdclang++"
)

if [[ -n "${CMAKE_COMPILER_LAUNCHER}" ]]; then
    cmake_args+=(
        -DCMAKE_C_COMPILER_LAUNCHER="${CMAKE_COMPILER_LAUNCHER}"
        -DCMAKE_CXX_COMPILER_LAUNCHER="${CMAKE_COMPILER_LAUNCHER}"
    )
fi

configure_args=(-S "${HRX_SRC_DIR}" -B "${HRX_BUILD_DIR}" -G "${CMAKE_GENERATOR}")
cmake "${configure_args[@]}" "${cmake_args[@]}" "$@"

cmake --build "${HRX_BUILD_DIR}" --config "${CMAKE_BUILD_TYPE}" --target install -j "${HRX_BUILD_JOBS:-$(nproc)}"
