#!/usr/bin/env bash
set -euo pipefail

LLAMA_SRC_DIR="${LLAMA_SRC_DIR:-$(git rev-parse --show-toplevel)}"
LLAMA_BUILD_DIR="${LLAMA_BUILD_DIR:-${LLAMA_SRC_DIR}/build-hrx}"
HRX_INSTALL_PREFIX="${HRX_INSTALL_PREFIX:-${RUNNER_TEMP:-/tmp}/hrx-install}"
CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
CMAKE_GENERATOR="${CMAKE_GENERATOR:-Ninja}"
GGML_HRX_AMDGPU_TARGETS="${GGML_HRX_AMDGPU_TARGETS:-gfx1100}"
GGML_HRX_BUILD_HIP_BENCHES="${GGML_HRX_BUILD_HIP_BENCHES:-OFF}"
LLAMA_BUILD_TARGET="${LLAMA_BUILD_TARGET:-}"

if [[ -z "${ROCM_PATH:-}" ]]; then
    if command -v hipconfig >/dev/null 2>&1; then
        ROCM_PATH="$(hipconfig -R)"
        export ROCM_PATH
    else
        ROCM_PATH="/opt/rocm"
        export ROCM_PATH
    fi
fi

CMAKE_PREFIX_PATH="${HRX_INSTALL_PREFIX}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
export CMAKE_PREFIX_PATH

cmake_args=(
    -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}"
    -DGGML_HRX=ON
    -DGGML_NATIVE=OFF
    -DGGML_HRX_ROCM_PATH="${ROCM_PATH}"
    -DGGML_HRX_AMDGPU_TARGETS="${GGML_HRX_AMDGPU_TARGETS}"
    -DGGML_HRX_BUILD_HIP_BENCHES="${GGML_HRX_BUILD_HIP_BENCHES}"
)

if [[ -x "${ROCM_PATH}/lib/llvm/bin/amdclang" ]]; then
    cmake_args+=(
        -DCMAKE_C_COMPILER="${ROCM_PATH}/lib/llvm/bin/amdclang"
        -DCMAKE_CXX_COMPILER="${ROCM_PATH}/lib/llvm/bin/amdclang++"
    )
fi

cmake -S "${LLAMA_SRC_DIR}" -B "${LLAMA_BUILD_DIR}" -G "${CMAKE_GENERATOR}" \
    "${cmake_args[@]}" \
    "$@"

build_args=(--build "${LLAMA_BUILD_DIR}" --config "${CMAKE_BUILD_TYPE}" -j "${LLAMA_BUILD_JOBS:-$(nproc)}")
if [[ -n "${LLAMA_BUILD_TARGET}" ]]; then
    build_args+=(--target "${LLAMA_BUILD_TARGET}")
fi

cmake "${build_args[@]}"
