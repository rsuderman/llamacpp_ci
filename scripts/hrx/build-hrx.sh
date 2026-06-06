#!/usr/bin/env bash
set -euo pipefail

HRX_SRC_DIR="${HRX_SRC_DIR:-${RUNNER_TEMP:-/tmp}/hrx-src}"
HRX_BUILD_DIR="${HRX_BUILD_DIR:-${RUNNER_TEMP:-/tmp}/hrx-build}"
HRX_INSTALL_PREFIX="${HRX_INSTALL_PREFIX:-${RUNNER_TEMP:-/tmp}/hrx-install}"
HRX_ROCM_ROOT="${HRX_ROCM_ROOT:-${ROCM_PATH:-}}"
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
CMAKE_GENERATOR="${CMAKE_GENERATOR:-Ninja}"

cmake_args=(
    -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}"
    -DCMAKE_INSTALL_PREFIX="${HRX_INSTALL_PREFIX}"
)

if [[ -n "${HRX_ROCM_ROOT}" ]]; then
    cmake_args+=(
        -DCMAKE_C_COMPILER="${HRX_ROCM_ROOT}/lib/llvm/bin/amdclang"
        -DCMAKE_CXX_COMPILER="${HRX_ROCM_ROOT}/lib/llvm/bin/amdclang++"
    )
    if [[ -x "${HRX_ROCM_ROOT}/lib/llvm/bin/llvm-ar" ]]; then
        cmake_args+=(-DCMAKE_AR="${HRX_ROCM_ROOT}/lib/llvm/bin/llvm-ar")
    fi
    if [[ -x "${HRX_ROCM_ROOT}/lib/llvm/bin/llvm-ranlib" ]]; then
        cmake_args+=(-DCMAKE_RANLIB="${HRX_ROCM_ROOT}/lib/llvm/bin/llvm-ranlib")
    fi
fi

cmake -S "${HRX_SRC_DIR}" -B "${HRX_BUILD_DIR}" -G "${CMAKE_GENERATOR}" \
    "${cmake_args[@]}" \
    "$@"

cmake --build "${HRX_BUILD_DIR}" --config "${CMAKE_BUILD_TYPE}" --target install -j "${HRX_BUILD_JOBS:-$(nproc)}"
